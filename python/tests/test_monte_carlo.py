"""Tests for python/monte_carlo.py — run with `pytest` from the python/ folder."""

import math
from statistics import NormalDist

import numpy as np
import pytest

import monte_carlo as mc


def black_scholes(S0, K, r, sigma, T, kind="call"):
    n = NormalDist()
    d1 = (math.log(S0 / K) + (r + 0.5 * sigma**2) * T) / (sigma * math.sqrt(T))
    d2 = d1 - sigma * math.sqrt(T)
    if kind == "call":
        return S0 * n.cdf(d1) - K * math.exp(-r * T) * n.cdf(d2)
    return K * math.exp(-r * T) * n.cdf(-d2) - S0 * n.cdf(-d1)


# --- reproducibility -------------------------------------------------------


def test_same_seed_same_result():
    a = mc.simulate_trades(0.5, 2.0, 1.0, 50, n_simulations=500, seed=3)
    b = mc.simulate_trades(0.5, 2.0, 1.0, 50, n_simulations=500, seed=3)
    assert np.array_equal(a.samples, b.samples)


def test_different_seed_different_result():
    a = mc.simulate_trades(0.5, 2.0, 1.0, 50, n_simulations=500, seed=3)
    b = mc.simulate_trades(0.5, 2.0, 1.0, 50, n_simulations=500, seed=4)
    assert not np.array_equal(a.samples, b.samples)


# --- trade simulation ------------------------------------------------------


def test_equity_curve_shape_and_start():
    curves = mc.equity_curves(0.5, 1.5, 1.0, n_trades=20, n_simulations=100, initial_capital=5_000, seed=1)
    assert curves.shape == (100, 21)
    assert np.all(curves[:, 0] == 5_000)


def test_zero_risk_keeps_capital():
    r = mc.simulate_trades(0.3, 1.0, 1.0, 100, n_simulations=200, risk_per_trade=0.0, seed=1)
    assert r.min_value == r.max_value == 10_000


def test_always_winning_compounds_exactly():
    r = mc.simulate_trades(1.0, 2.0, 1.0, 10, n_simulations=50, risk_per_trade=0.01, seed=1)
    assert r.mean == pytest.approx(10_000 * 1.02**10)


def test_always_losing_compounds_exactly():
    r = mc.simulate_trades(0.0, 2.0, 1.0, 10, n_simulations=50, risk_per_trade=0.01, seed=1)
    assert r.mean == pytest.approx(10_000 * 0.99**10)


def test_capital_floored_at_zero():
    r = mc.simulate_trades(0.0, 1.0, 2.0, 5, n_simulations=10, risk_per_trade=0.6, seed=1)
    assert r.max_value == 0.0


def test_positive_expectancy_mostly_profitable():
    r = mc.simulate_trades(0.55, 1.5, 1.0, 200, n_simulations=5_000, seed=11)
    assert r.prob_above(10_000) > 0.8


@pytest.mark.parametrize(
    "bad",
    [
        dict(win_rate=1.2),
        dict(win_rate=-0.1),
        dict(avg_win=-1.0),
        dict(n_trades=0),
        dict(risk_per_trade=1.5),
    ],
)
def test_invalid_inputs_rejected(bad):
    args = dict(win_rate=0.5, avg_win=1.0, avg_loss=1.0, n_trades=10, risk_per_trade=0.01)
    args.update(bad)
    with pytest.raises(ValueError):
        mc.simulate_trades(**args, n_simulations=10)


# --- drawdown and ruin -----------------------------------------------------


def test_drawdown_bounds():
    dd = mc.simulate_drawdown(0.5, 1.0, 1.0, 100, n_simulations=1_000, seed=5)
    assert 0.0 <= dd.min_value <= dd.max_value < 1.0


def test_drawdown_of_losing_streak():
    dd = mc.simulate_drawdown(0.0, 1.0, 1.0, 10, n_simulations=10, risk_per_trade=0.01, seed=5)
    assert dd.mean == pytest.approx(1 - 0.99**10)


def test_drawdown_grows_with_risk():
    low = mc.simulate_drawdown(0.5, 1.5, 1.0, 200, n_simulations=2_000, risk_per_trade=0.005, seed=9)
    high = mc.simulate_drawdown(0.5, 1.5, 1.0, 200, n_simulations=2_000, risk_per_trade=0.03, seed=9)
    assert high.median > low.median


def test_ruin_extremes():
    assert mc.risk_of_ruin(1.0, 1.0, 1.0, 0.02, 0.5, 100, n_simulations=200, seed=1) == 0.0
    assert mc.risk_of_ruin(0.0, 1.0, 1.0, 0.02, 0.5, 100, n_simulations=200, seed=1) == 1.0


def test_ruin_threshold_reached_exactly_when_expected():
    # 0.98^35 = 0.493 < 0.5 but 0.98^34 = 0.503 > 0.5
    assert mc.risk_of_ruin(0.0, 1.0, 1.0, 0.02, 0.5, 34, n_simulations=20, seed=1) == 0.0
    assert mc.risk_of_ruin(0.0, 1.0, 1.0, 0.02, 0.5, 35, n_simulations=20, seed=1) == 1.0


def test_ruin_increases_with_risk():
    a = mc.risk_of_ruin(0.5, 1.2, 1.0, 0.01, 0.3, 300, n_simulations=3_000, seed=2)
    b = mc.risk_of_ruin(0.5, 1.2, 1.0, 0.05, 0.3, 300, n_simulations=3_000, seed=2)
    assert b > a


# --- prices, options, VaR ---------------------------------------------------


def test_gbm_shape_and_mean():
    paths = mc.geometric_brownian_motion(100, 0.05, 0.2, 1.0, 252, n_simulations=20_000, seed=8)
    assert paths.shape == (20_000, 253)
    assert np.all(paths[:, 0] == 100)
    assert np.mean(paths[:, -1]) == pytest.approx(100 * math.exp(0.05), rel=0.01)


@pytest.mark.parametrize("kind", ["call", "put"])
def test_option_price_matches_black_scholes(kind):
    price, se = mc.monte_carlo_option_price(100, 105, 0.05, 0.2, 1.0, kind, n_simulations=200_000, seed=21)
    assert abs(price - black_scholes(100, 105, 0.05, 0.2, 1.0, kind)) < 4 * se


def test_option_type_validated():
    with pytest.raises(ValueError):
        mc.monte_carlo_option_price(100, 100, 0.0, 0.2, 1.0, "straddle")


def test_historical_var_known_sample():
    returns = np.linspace(-0.05, 0.05, 101)  # 5th percentile = -0.045
    assert mc.calculate_var(returns, 0.95, 10_000, "historical") == pytest.approx(450.0)


def test_parametric_var_matches_formula():
    rng = np.random.default_rng(0)
    returns = rng.normal(0.001, 0.02, 5_000)
    expected = -(returns.mean() + returns.std() * NormalDist().inv_cdf(0.05)) * 10_000
    assert mc.calculate_var(returns, 0.95, 10_000, "parametric") == pytest.approx(expected)


def test_monte_carlo_var_close_to_analytic():
    v = mc.monte_carlo_var(0.0, 0.02, 100_000, 1, 0.99, n_simulations=200_000, seed=4)
    analytic = -NormalDist(0.0, 0.02).inv_cdf(0.01) * 100_000
    assert v == pytest.approx(analytic, rel=0.02)


def test_generic_engine_uses_generator():
    res = mc.monte_carlo(lambda rng: rng.normal(5.0, 1.0), n_simulations=5_000, seed=1)
    assert res.mean == pytest.approx(5.0, abs=0.05)
    lo, hi = res.confidence_interval(0.90)
    assert lo < res.median < hi
