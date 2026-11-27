# Security policy

## Reporting a vulnerability

Use GitHub's **Report a vulnerability** button (Security tab) so the report stays private.
Please do not open a public issue for a security problem. You will get an answer within 7 days.

## Secrets

- No token, chat ID, API key, licence key or account number is ever written in the code.
  Programs read them from input parameters (MQL5, NinjaScript) or environment variables (Python).
- Every pull request is scanned by gitleaks and by `tools/check_repo.py`.
- If a secret is committed by mistake: **revoke it first** (BotFather `/revoke` for Telegram,
  the provider's console for API keys), then remove it from the code. Deleting the line does not
  remove it from the git history.
