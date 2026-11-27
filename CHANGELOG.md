# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each product keeps its own version in `#property version`; this file records repository-level changes.

## 2026-11-27 — Repository restructure

### Changed
- `mql5/` now mirrors the terminal's `MQL5` folder (`Experts/`, `Indicators/`, `Scripts/`, `Include/`, `Presets/`): copy it as is and every `#include` resolves. Example EAs include libraries with `<AlgoSphere\...>`.
- `ninjatrader/` split into `Indicators/` and `Strategies/`; `DollarBasedSwingBreakStrategy.cs` moved to `Strategies/`, `Sola1.cs` to `Indicators/`.
- Risk notes moved to `docs/risk/` (Monte Carlo note renumbered 03); product pages in `docs/products/`, screenshots in `docs/images/`.
- Version suffix dropped from file names (`ASQ_CommandDesk_v1.00.mq5` → `ASQ_CommandDesk.mq5`); versions live in `#property version`.
- `python/monte_carlo.py` rewritten: vectorised with NumPy (risk of ruin on 10,000 × 500 trades: 1.2 s → 0.07 s), reproducible with `seed=`, input validation, no SciPy dependency. `monte_carlo()` now passes a `numpy.random.Generator` to the simulated function.

### Added
- Sources of ASQ PropGuard v2, ASQ RiskReward v2, ASQ JournalExport v2 and ASQ Safe Scalping v1.10, previously only inside zip files, with their presets, Monte Carlo report and product pages.
- `tools/check_repo.py` and a GitHub Actions workflow (repository checks, Python lint and 29 tests, gitleaks).
- `.gitattributes`, `.editorconfig`, `SECURITY.md`, pull-request and bug-report templates.

### Fixed
- **ASQ Safe Scalping 1.11** — in risk mode, a lot below the broker minimum was raised to the minimum, so the trade risked more than the configured percentage. The trade is now skipped and logged; the risk lot is rounded down to the volume step. Fixed-lot mode (the default) is unchanged.
- `docs/risk/README.md` — the NinjaScript sizing example ignored the instrument's point value and over-sized futures positions (5× on MES).
- Broken links between the risk notes.

### Removed from the public tree (kept in git history and in a private export)
- Commercial packages and third-party or co-owned code: AlgoSphere Quant suite v2.10, Sophon packages, CorrelationMatrixPro, TradingAnalyticsSuite, AVGoldAsianBreakout, SMC_LiquidityMap, ExMachina legacy sources and screenshots, AnaCristina screenshots.
- Superseded versions: SafeScalperPro v3 (replaced by ASQ Safe Scalping 1.11), ASQ PropDashboard (replaced by ASQ PropGuard v2), ASQ_Legacy tools, single-file Safe Scalping Code Base copy.
- Archives (`*.zip`, `*.tar.gz`), the empty `VWAPx.cs` and `Torpedo.md`, marketing texts for products not in this repository, the Solidity learning contract.

### Known issues
- `ASQ_PropGuard` auto-close does not run: trade functions are refused inside indicators (error 4014).
