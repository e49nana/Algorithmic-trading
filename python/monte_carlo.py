"""
Monte Carlo utilities for strategy validation and risk metrics.

Every simulation is vectorised with NumPy and reproducible through ``seed``.
The trade simulators use fixed-fractional sizing: each trade risks
``risk_per_trade`` of the current capital and wins ``avg_win`` R or loses
``avg_loss`` R.

Author: Emmanuel Nana Nana (AlgoSphere Quant)
Repository: https://github.com/e49nana/algorithmic-trading
"""

from __future__ import annotations

from dataclasses import dataclass
from statistics import NormalDist
from typing import Callable, Optional, Tuple

import numpy as np

__all__ = [
    "SimulationResult",
    "monte_carlo",
    "equity_curves",
    "simulate_trades",
    "simulate_drawdown",
    "risk_of_ruin",
    "geometric_brownian_motion",
    "monte_carlo_option_price",
    "calculate_var",
    "monte_carlo_var",
]


# =============================================================================
# RESULT CONTAINER
# =============================================================================


@dataclass
class SimulationResult:
    """Summary statistics and raw samples of one simulation."""

    mean: float
    std: float
    median: float
    percentile_5: float
    percentile_95: float
    min_value: float
    max_value: float
    samples: np.ndarray

    @classmethod
    def from_samples(cls, samples: np.ndarray) -> "SimulationResult":
        samples = np.asarray(samples, dtype=float)
        return cls(
            mean=float(np.mean(samples)),
            std=float(np.std(samples)),
            median=float(np.median(samples)),
            percentile_5=float(np.percentile(samples, 5)),
            percentile_95=float(np.percentile(samples, 95)),
            min_value=float(np.min(samples)),
            max_value=float(np.max(samples)),
            samples=samples,
        )

    def confidence_interval(self, level: float = 0.95) -> Tuple[float, float]:
        """Two-sided empirical interval containing ``level`` of the samples."""
        alpha = (1.0 - level) / 2.0
        lower, upper = np.percentile(self.samples, [alpha * 100, (1.0 - alpha) * 100])
        return float(lower), float(upper)

    def prob_above(self, threshold: float) -> float:
        """Share of samples strictly above ``threshold``."""
        return float(np.mean(self.samples > threshold))

    def prob_below(self, threshold: float) -> float:
        """Share of samples strictly below ``threshold``."""
        return float(np.mean(self.samples < threshold))


# =============================================================================
# GENERIC ENGINE
# =============================================================================


def monte_carlo(
    simulation_func: Callable[[np.random.Generator], float],
    n_simulations: int = 10_000,
    seed: Optional[int] = None,
) -> SimulationResult:
    """
    Run ``simulation_func`` ``n_simulations`` times and summarise the outcomes.

    ``simulation_func`` receives a ``numpy.random.Generator`` and returns one
    outcome. Prefer the vectorised helpers below for trading questions: this
    generic loop runs in Python and is slow beyond ~10^5 draws.

    >>> res = monte_carlo(lambda rng: 1.0 if rng.random() > 0.5 else -1.0, 2000, seed=1)
    >>> abs(res.mean) < 0.1
    True
    """
    rng = np.random.default_rng(seed)
    samples = np.fromiter(
        (simulation_func(rng) for _ in range(n_simulations)), dtype=float, count=n_simulations
    )
    return SimulationResult.from_samples(samples)


# =============================================================================
# TRADING
# =============================================================================


def _validate_trade_inputs(
    win_rate: float, avg_win: float, avg_loss: float, n_trades: int, risk_per_trade: float
) -> None:
    if not 0.0 <= win_rate <= 1.0:
        raise ValueError("win_rate must be in [0, 1]")
    if avg_win < 0 or avg_loss < 0:
        raise ValueError("avg_win and avg_loss are R-multiples and must be >= 0")
    if n_trades < 1:
        raise ValueError("n_trades must be >= 1")
    if not 0.0 <= risk_per_trade <= 1.0:
        raise ValueError("risk_per_trade is a fraction of capital in [0, 1]")


def equity_curves(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    n_trades: int,
    n_simulations: int = 10_000,
    initial_capital: float = 10_000.0,
    risk_per_trade: float = 0.01,
    seed: Optional[int] = None,
) -> np.ndarray:
    """
    Simulated equity after each trade, shape ``(n_simulations, n_trades + 1)``.

    Column 0 is the initial capital. Capital is floored at 0 (an account that
    reaches 0 stays at 0).
    """
    _validate_trade_inputs(win_rate, avg_win, avg_loss, n_trades, risk_per_trade)
    rng = np.random.default_rng(seed)
    wins = rng.random((n_simulations, n_trades)) < win_rate
    growth = np.where(wins, 1.0 + risk_per_trade * avg_win, 1.0 - risk_per_trade * avg_loss)
    np.clip(growth, 0.0, None, out=growth)
    curves = np.empty((n_simulations, n_trades + 1))
    curves[:, 0] = initial_capital
    np.cumprod(growth, axis=1, out=curves[:, 1:])
    curves[:, 1:] *= initial_capital
    return curves


def simulate_trades(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    n_trades: int,
    n_simulations: int = 10_000,
    initial_capital: float = 10_000.0,
    risk_per_trade: float = 0.01,
    seed: Optional[int] = None,
) -> SimulationResult:
    """
    Distribution of final capital after ``n_trades``.

    >>> r = simulate_trades(0.55, 1.5, 1.0, n_trades=100, seed=7)
    >>> r.prob_above(10_000) > 0.5
    True
    """
    curves = equity_curves(
        win_rate, avg_win, avg_loss, n_trades, n_simulations, initial_capital, risk_per_trade, seed
    )
    return SimulationResult.from_samples(curves[:, -1])


def simulate_drawdown(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    n_trades: int,
    n_simulations: int = 10_000,
    risk_per_trade: float = 0.01,
    seed: Optional[int] = None,
) -> SimulationResult:
    """
    Distribution of the maximum peak-to-trough drawdown, as a fraction (0.12 = 12 %).

    The result does not depend on the starting capital, only on the sizing.
    """
    curves = equity_curves(win_rate, avg_win, avg_loss, n_trades, n_simulations, 1.0, risk_per_trade, seed)
    peaks = np.maximum.accumulate(curves, axis=1)
    max_dd = np.max((peaks - curves) / peaks, axis=1)
    return SimulationResult.from_samples(max_dd)


def risk_of_ruin(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    risk_per_trade: float = 0.02,
    ruin_threshold: float = 0.5,
    n_trades: int = 500,
    n_simulations: int = 10_000,
    seed: Optional[int] = None,
) -> float:
    """
    Probability that equity falls to ``1 - ruin_threshold`` of its start
    (0.5 = losing half the account) at any point within ``n_trades``.
    """
    if not 0.0 < ruin_threshold <= 1.0:
        raise ValueError("ruin_threshold must be in (0, 1]")
    curves = equity_curves(win_rate, avg_win, avg_loss, n_trades, n_simulations, 1.0, risk_per_trade, seed)
    ruined = np.any(curves[:, 1:] <= 1.0 - ruin_threshold, axis=1)
    return float(np.mean(ruined))


# =============================================================================
# PRICES AND OPTIONS
# =============================================================================


def geometric_brownian_motion(
    S0: float,
    mu: float,
    sigma: float,
    T: float,
    n_steps: int,
    n_simulations: int = 10_000,
    seed: Optional[int] = None,
) -> np.ndarray:
    """
    Price paths following dS = mu S dt + sigma S dW, shape ``(n_simulations, n_steps + 1)``.
    """
    rng = np.random.default_rng(seed)
    dt = T / n_steps
    shocks = (mu - 0.5 * sigma**2) * dt + sigma * np.sqrt(dt) * rng.standard_normal((n_simulations, n_steps))
    paths = np.empty((n_simulations, n_steps + 1))
    paths[:, 0] = S0
    paths[:, 1:] = S0 * np.exp(np.cumsum(shocks, axis=1))
    return paths


def monte_carlo_option_price(
    S0: float,
    K: float,
    r: float,
    sigma: float,
    T: float,
    option_type: str = "call",
    n_simulations: int = 100_000,
    seed: Optional[int] = None,
) -> Tuple[float, float]:
    """European option price and its standard error: ``(price, std_error)``."""
    kind = option_type.lower()
    if kind not in ("call", "put"):
        raise ValueError("option_type must be 'call' or 'put'")
    rng = np.random.default_rng(seed)
    z = rng.standard_normal(n_simulations)
    st = S0 * np.exp((r - 0.5 * sigma**2) * T + sigma * np.sqrt(T) * z)
    payoffs = np.maximum(st - K, 0.0) if kind == "call" else np.maximum(K - st, 0.0)
    discount = np.exp(-r * T)
    price = discount * float(np.mean(payoffs))
    std_error = discount * float(np.std(payoffs, ddof=1)) / np.sqrt(n_simulations)
    return float(price), float(std_error)


# =============================================================================
# VALUE AT RISK
# =============================================================================


def calculate_var(
    returns: np.ndarray,
    confidence_level: float = 0.95,
    investment: float = 10_000.0,
    method: str = "historical",
) -> float:
    """
    Value at Risk in currency units (positive number = potential loss).

    ``method`` is ``"historical"`` (empirical quantile) or ``"parametric"``
    (normal distribution fitted on ``returns``).
    """
    returns = np.asarray(returns, dtype=float)
    if method == "historical":
        var_pct = float(np.percentile(returns, (1.0 - confidence_level) * 100))
    elif method == "parametric":
        z = NormalDist().inv_cdf(1.0 - confidence_level)
        var_pct = float(np.mean(returns)) + float(np.std(returns)) * z
    else:
        raise ValueError("method must be 'historical' or 'parametric'")
    return -var_pct * investment


def monte_carlo_var(
    mu: float,
    sigma: float,
    investment: float = 10_000.0,
    horizon_days: int = 1,
    confidence_level: float = 0.95,
    n_simulations: int = 10_000,
    seed: Optional[int] = None,
) -> float:
    """VaR in currency units from normally distributed simulated returns."""
    rng = np.random.default_rng(seed)
    simulated = rng.normal(mu * horizon_days, sigma * np.sqrt(horizon_days), n_simulations)
    values = investment * (1.0 + simulated)
    return float(investment - np.percentile(values, (1.0 - confidence_level) * 100))


# =============================================================================
# DEMO
# =============================================================================

if __name__ == "__main__":
    line = "=" * 60
    print(line, "MONTE CARLO DEMO", line, sep="\n")

    res = simulate_trades(0.55, 1.5, 1.0, n_trades=100, risk_per_trade=0.01, seed=42)
    lo, hi = res.confidence_interval(0.90)
    print("\n1. 55% win rate, 1.5R / 1R, 100 trades, 1% risk, start 10,000")
    print(f"   median final capital : {res.median:,.2f}")
    print(f"   90% interval         : {lo:,.2f} - {hi:,.2f}")
    print(f"   P(profit)            : {res.prob_above(10_000):.1%}")

    dd = simulate_drawdown(0.55, 1.5, 1.0, n_trades=100, risk_per_trade=0.01, seed=42)
    print(f"   median max drawdown  : {dd.median:.1%} (95th pct {dd.percentile_95:.1%})")

    print("\n2. Risk of losing 50% within 500 trades")
    for risk in (0.01, 0.02, 0.05):
        print(f"   {risk:.0%} per trade : {risk_of_ruin(0.55, 1.5, 1.0, risk, 0.5, 500, seed=42):.2%}")

    price, se = monte_carlo_option_price(100, 105, 0.05, 0.2, 1.0, "call", seed=42)
    print(f"\n3. Call S0=100 K=105 r=5% sigma=20% T=1y : {price:.4f} +/- {1.96 * se:.4f}")

    v95 = monte_carlo_var(0.0005, 0.02, 100_000, 1, 0.95, seed=42)
    v99 = monte_carlo_var(0.0005, 0.02, 100_000, 1, 0.99, seed=42)
    print(f"\n4. 1-day VaR on 100,000 (2% daily vol): 95% {v95:,.0f} | 99% {v99:,.0f}")
