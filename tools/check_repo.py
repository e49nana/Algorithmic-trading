#!/usr/bin/env python3
"""
Repository hygiene checks — run locally with `python tools/check_repo.py`, run in CI on every PR.

Fails (exit 1) on:
  * archives, compiled binaries, oversized or empty files
  * anything that looks like a secret (bot tokens, API keys, private keys, hard-coded chat IDs)
  * text files that are not valid UTF-8
  * MQL5 files outside the MetaTrader layout, wrong event handlers for their folder,
    unresolved #include, missing #property copyright/version, foreign copyright or link
  * trade or system calls that MetaTrader refuses inside indicators (OrderSend, OrderCalcMargin, Sleep...)
  * NinjaScript files whose class or namespace does not match their folder
  * broken relative links or images in Markdown files
  * source files missing from the README catalogue

Known, tracked defects are listed in KNOWN_ISSUES: they print a warning instead of failing.
Standard library only, Python 3.10+.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# ----------------------------------------------------------------------------- policy
OWNER_PATTERN = re.compile(r"algosphere", re.IGNORECASE)  # required in #property copyright
ALLOWED_LINK_HOSTS = ("mql5.com/en/users/robin2.0", "algosphere-quant.com")
FORBIDDEN_EXT = {".zip", ".gz", ".tgz", ".tar", ".rar", ".7z", ".ex4", ".ex5", ".dll", ".exe", ".so", ".pyc"}
TEXT_EXT = {".mq5", ".mqh", ".cs", ".py", ".md", ".set", ".txt", ".yml", ".yaml", ".toml", ".html", ".json",
            ".cfg", ".ini", ".sol"}
MAX_BYTES = 1_000_000
MAX_IMAGE_BYTES = 600_000
MQL5_DIRS = {"Experts", "Indicators", "Scripts", "Include", "Presets", "Files"}
MQL5_STD_INCLUDES = {"Trade", "Arrays", "Controls", "ChartObjects", "Charts", "Canvas", "Files", "Generic",
                     "Graphics", "Indicators", "Math", "Object.mqh", "Strings", "Tools", "Expert", "StdLibErr.mqh",
                     "MovingAverages.mqh", "WinAPI"}
README_CATALOGUE_EXT = {".mq5", ".mqh", ".cs"}

# path -> issue reference; the check still runs but only warns
KNOWN_ISSUES: dict[str, str] = {
    "mql5/Indicators/AlgoSphere/ASQ_PropGuard.mq5":
        "auto-close calls PositionClose() from an indicator, which MetaTrader blocks; "
        "move the protection to an EA (see CHANGELOG, Known issues)",
}

SECRET_PATTERNS = {
    "Telegram bot token": re.compile(r"\b\d{8,10}:AA[0-9A-Za-z_-]{30,}\b"),
    "Anthropic API key": re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}"),
    "OpenAI-style key": re.compile(r"\bsk-[A-Za-z0-9]{32,}\b"),
    "GitHub token": re.compile(r"\b(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,})\b"),
    "AWS access key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "private key": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "hard-coded token/chat id": re.compile(
        r"(?i)\b\w*(token|chat_?id|api_?key|secret|password)\w*\s*=\s*\"[^\"\s]{6,}\""),
}

# Functions MetaTrader refuses inside indicators (error 4014), plus CTrade calls that wrap OrderSend.
# Source: MQL5 book, "Main characteristics of indicators".
INDICATOR_FORBIDDEN = re.compile(
    r"\b(OrderSend|OrderSendAsync|OrderCalcMargin|OrderCalcProfit|OrderCheck|SendFTP|WebRequest|"
    r"Socket\w+|Sleep|MessageBox|ExpertRemove|CTrade)\b|"
    r"\.(PositionClose|PositionOpen|PositionModify|Buy|Sell|BuyStop|SellStop|BuyLimit|SellLimit)\s*\(")
INCLUDE = re.compile(r'^\s*#include\s*([<"])([^>"]+)[>"]', re.MULTILINE)
MD_LINK = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)|<img[^>]+src=\"([^\"]+)\"")

errors: list[str] = []
warnings: list[str] = []


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def fail(path: str, msg: str) -> None:
    if path in KNOWN_ISSUES:
        warnings.append(f"{path}: {msg}  [known issue: {KNOWN_ISSUES[path]}]")
    else:
        errors.append(f"{path}: {msg}")


def tracked_files() -> list[Path]:
    try:
        out = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                             cwd=ROOT, check=True, capture_output=True).stdout
        return sorted(ROOT / p for p in out.decode().split("\0") if p and (ROOT / p).is_file())
    except (OSError, subprocess.CalledProcessError):
        return sorted(p for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts)


def strip_comments(code: str) -> str:
    code = re.sub(r"/\*.*?\*/", " ", code, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", code)


# ----------------------------------------------------------------------------- checks
def check_file_basics(p: Path, text: str | None) -> None:
    r, size = rel(p), p.stat().st_size
    if p.suffix.lower() in FORBIDDEN_EXT:
        fail(r, f"{p.suffix} files do not belong in git: publish builds as GitHub Release assets")
    limit = MAX_IMAGE_BYTES if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".gif"} else MAX_BYTES
    if size > limit:
        fail(r, f"{size:,} bytes exceeds the {limit:,} byte limit")
    if size == 0 or (text is not None and not text.strip()):
        fail(r, "empty file")


def check_secrets(r: str, text: str) -> None:
    for name, pattern in SECRET_PATTERNS.items():
        for m in pattern.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            fail(r, f"line {line}: possible {name} — use an input parameter or an environment variable")


def check_mql5(p: Path, text: str) -> None:
    r = rel(p)
    parts = p.relative_to(ROOT / "mql5").parts
    if parts[0] not in MQL5_DIRS:
        fail(r, f"top folder must be one of {sorted(MQL5_DIRS)} (mirror of the terminal's MQL5 folder)")
        return
    if p.suffix == ".set":
        return
    code = strip_comments(text)
    if p.suffix == ".mqh" and parts[0] != "Include":
        fail(r, ".mqh files live under mql5/Include/")
    if p.suffix == ".mq5":
        handlers = set(re.findall(r"\b(OnTick|OnTimer|OnChartEvent|OnTrade|OnCalculate|OnStart)\s*\(", code))
        expected = {"Experts": {"OnTick", "OnTimer", "OnChartEvent", "OnTrade"},
                    "Indicators": {"OnCalculate"}, "Scripts": {"OnStart"}}.get(parts[0])
        if expected and not handlers & expected:
            fail(r, f"a program in {parts[0]}/ needs one of {sorted(expected)}")
        if parts[0] == "Experts" and "OnCalculate" in handlers:
            fail(r, "defines OnCalculate: indicators belong in mql5/Indicators/")
        if parts[0] == "Indicators":
            calls = sorted({m.group(1) or m.group(2) for m in INDICATOR_FORBIDDEN.finditer(code)})
            if calls:
                fail(r, f"calls {', '.join(calls)}: refused inside indicators (error 4014), move them to an EA")
        if not re.search(r"#property\s+version\s+\"\d+\.\d+\"", text):
            fail(r, "missing #property version \"X.YY\"")
    m = re.search(r"#property\s+copyright\s+\"([^\"]*)\"", text)
    if p.suffix == ".mq5" and not m:
        fail(r, "missing #property copyright")
    if m and not OWNER_PATTERN.search(m.group(1)):
        fail(r, f"copyright \"{m.group(1)}\" is not ours: confirm the right to publish or remove the file")
    link = re.search(r"#property\s+link\s+\"([^\"]*)\"", text)
    if link and not any(h in link.group(1) for h in ALLOWED_LINK_HOSTS):
        fail(r, f"#property link \"{link.group(1)}\" points outside {ALLOWED_LINK_HOSTS}")
    for kind, target in INCLUDE.findall(code):
        target = target.replace("\\", "/")
        if kind == '"':
            if not (p.parent / target).is_file():
                fail(r, f'#include "{target}" not found next to the file')
        elif not (ROOT / "mql5" / "Include" / target).is_file() and target.split("/")[0] not in MQL5_STD_INCLUDES:
            fail(r, f"#include <{target}> not found in mql5/Include/ nor in the MQL5 standard library")


def check_ninjascript(p: Path, text: str) -> None:
    r = rel(p)
    folder = p.relative_to(ROOT / "ninjatrader").parts[0]
    base = {"Indicators": "Indicator", "Strategies": "Strategy"}.get(folder)
    if base is None:
        fail(r, "NinjaScript files live in ninjatrader/Indicators/ or ninjatrader/Strategies/")
        return
    code = strip_comments(text)
    if not re.search(rf"class\s+\w+\s*:\s*{base}\b", code):
        fail(r, f"no class deriving from {base} in a {folder}/ file")
    if not re.search(rf"namespace\s+NinjaTrader\.NinjaScript\.{folder}\b", code):
        fail(r, f"namespace must be NinjaTrader.NinjaScript.{folder}")


def check_markdown_links(p: Path, text: str) -> None:
    r = rel(p)
    code_free = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    code_free = re.sub(r"`[^`\n]*`", "", code_free)
    for m in MD_LINK.finditer(code_free):
        target = (m.group(1) or m.group(2) or "").split("#")[0]
        if not target or re.match(r"^[a-z][a-z0-9+.-]*:", target, re.IGNORECASE):
            continue
        if not (p.parent / target).resolve().exists():
            fail(r, f"broken link -> {target}")


def check_readme_catalogue(files: list[Path]) -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for p in files:
        if p.suffix in README_CATALOGUE_EXT and p.stem not in readme:
            fail(rel(p), "not listed in README.md: add it to the catalogue or remove it")


def main() -> int:
    files = tracked_files()
    for p in files:
        r = rel(p)
        text = None
        if p.suffix.lower() in TEXT_EXT or p.name in {"README", "LICENSE", ".gitignore", ".gitattributes",
                                                        ".editorconfig"}:
            try:
                text = p.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                fail(r, "not valid UTF-8 (MetaEditor: File > Save As > UTF-8)")
        check_file_basics(p, text)
        if text is None:
            continue
        if not r.startswith("tools/check_repo.py"):
            check_secrets(r, text)
        if r.startswith("mql5/"):
            check_mql5(p, text)
        elif r.startswith("ninjatrader/") and p.suffix == ".cs":
            check_ninjascript(p, text)
        if p.suffix == ".md":
            check_markdown_links(p, text)
    check_readme_catalogue(files)

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"\n{len(files)} files checked: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
