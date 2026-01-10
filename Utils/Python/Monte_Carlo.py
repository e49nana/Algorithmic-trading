"""
Monte Carlo Simulation Utilities
=================================
Tools for probabilistic analysis and risk assessment.
Applications: Trading strategy validation, option pricing, risk metrics.

Author: Emmanuel Nana Nana
Repo: Side-Activities / Algorithmic-trading
"""

import numpy as np
from typing import Callable, Tuple, List, Optional
from dataclasses import dataclass


@dataclass
class SimulationResult:
    """Container for Monte Carlo simulation results."""
    mean: float
    std: float
    median: float
    percentile_5: float
    percentile_95: float
    min_value: float
    max_value: float
    samples: np.ndarray
    
    def confidence_interval(self, level: float = 0.95) -> Tuple[float, float]:
        """Return confidence interval at given level."""
        alpha = (1 - level) / 2
        lower = np.percentile(self.samples, alpha * 100)
        upper = np.percentile(self.samples, (1 - alpha) * 100)
        return (lower, upper)
    
    def prob_above(self, threshold: float) -> float:
        """Probability of outcome above threshold."""
        return np.mean(self.samples > threshold)
    
    def prob_below(self, threshold: float) -> float:
        """Probability of outcome below threshold."""
        return np.mean(self.samples < threshold)
    
    def __repr__(self) -> str:
        return (
            f"SimulationResult(\n"
            f"  mean={self.mean:.4f}, std={self.std:.4f}\n"
            f"  median={self.median:.4f}\n"
            f"  95% CI=[{self.percentile_5:.4f}, {self.percentile_95:.4f}]\n"
            f"  range=[{self.min_value:.4f}, {self.max_value:.4f}]\n"
            f"  n_samples={len(self.samples)}\n"
            f")"
        )


# =============================================================================
# CORE MONTE CARLO ENGINE
# =============================================================================

def monte_carlo(
    simulation_func: Callable[[], float],
    n_simulations: int = 10000,
    seed: Optional[int] = None
) -> SimulationResult:
    """
    Run Monte Carlo simulation.
    
    Parameters
    ----------
    simulation_func : Callable
        Function that returns one random outcome
    n_simulations : int
        Number of simulations to run
    seed : int, optional
        Random seed for reproducibility
        
    Returns
    -------
    SimulationResult
        Statistics and samples from simulation
    
    Example
    -------
    >>> def coin_flip_game():
    ...     return 1 if np.random.random() > 0.5 else -1
    >>> result = monte_carlo(coin_flip_game, n_simulations=10000)
    >>> print(result.mean)  # Should be close to 0
    """
    if seed is not None:
        np.random.seed(seed)
    
    samples = np.array([simulation_func() for _ in range(n_simulations)])
    
    return SimulationResult(
        mean=np.mean(samples),
        std=np.std(samples),
        median=np.median(samples),
        percentile_5=np.percentile(samples, 5),
        percentile_95=np.percentile(samples, 95),
        min_value=np.min(samples),
        max_value=np.max(samples),
        samples=samples
    )


# =============================================================================
# TRADING APPLICATIONS
# =============================================================================

def simulate_trades(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    n_trades: int,
    n_simulations: int = 10000,
    initial_capital: float = 10000,
    risk_per_trade: float = 0.01
) -> SimulationResult:
    """
    Monte Carlo simulation of a trading strategy.
    
    Parameters
    ----------
    win_rate : float
        Probability of winning trade (0-1)
    avg_win : float
        Average win in R-multiples (e.g., 2.0 = 2R)
    avg_loss : float
        Average loss in R-multiples (usually 1.0 = 1R)
    n_trades : int
        Number of trades to simulate
    n_simulations : int
        Number of equity curves to generate
    initial_capital : float
        Starting capital
    risk_per_trade : float
        Fraction of capital risked per trade
        
    Returns
    -------
    SimulationResult
        Final equity distribution
    
    Example
    -------
    >>> # 55% win rate, 1.5:1 reward/risk
    >>> result = simulate_trades(
    ...     win_rate=0.55, avg_win=1.5, avg_loss=1.0,
    ...     n_trades=100, n_simulations=10000
    ... )
    >>> print(f"Expected final capital: €{result.mean:.2f}")
    >>> print(f"Probability of profit: {result.prob_above(10000)*100:.1f}%")
    """
    def single_simulation():
        capital = initial_capital
        for _ in range(n_trades):
            risk_amount = capital * risk_per_trade
            if np.random.random() < win_rate:
                capital += risk_amount * avg_win
            else:
                capital -= risk_amount * avg_loss
            if capital <= 0:
                return 0
        return capital
    
    return monte_carlo(single_simulation, n_simulations)


def simulate_drawdown(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    n_trades: int,
    n_simulations: int = 10000
) -> SimulationResult:
    """
    Simulate maximum drawdown distribution.
    
    Returns
    -------
    SimulationResult
        Maximum drawdown distribution (as positive percentages)
    """
    def single_simulation():
        capital = 10000
        peak = capital
        max_dd = 0
        
        for _ in range(n_trades):
            risk_amount = capital * 0.01
            if np.random.random() < win_rate:
                capital += risk_amount * avg_win
            else:
                capital -= risk_amount * avg_loss
            
            if capital > peak:
                peak = capital
            
            dd = (peak - capital) / peak
            if dd > max_dd:
                max_dd = dd
                
            if capital <= 0:
                return 1.0  # 100% drawdown
        
        return max_dd
    
    return monte_carlo(single_simulation, n_simulations)


def risk_of_ruin(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    risk_per_trade: float = 0.02,
    ruin_threshold: float = 0.5,
    n_trades: int = 500,
    n_simulations: int = 10000
) -> float:
    """
    Calculate probability of losing X% of capital (risk of ruin).
    
    Parameters
    ----------
    win_rate : float
        Win probability
    avg_win : float
        Average win in R
    avg_loss : float
        Average loss in R
    risk_per_trade : float
        Risk per trade as fraction
    ruin_threshold : float
        What counts as "ruin" (0.5 = 50% loss)
    n_trades : int
        Trading horizon
    n_simulations : int
        Number of simulations
        
    Returns
    -------
    float
        Probability of ruin (0-1)
    """
    ruin_count = 0
    ruin_level = 10000 * (1 - ruin_threshold)
    
    for _ in range(n_simulations):
        capital = 10000
        for _ in range(n_trades):
            risk_amount = capital * risk_per_trade
            if np.random.random() < win_rate:
                capital += risk_amount * avg_win
            else:
                capital -= risk_amount * avg_loss
            
            if capital <= ruin_level:
                ruin_count += 1
                break
    
    return ruin_count / n_simulations


# =============================================================================
# FINANCIAL APPLICATIONS
# =============================================================================

def geometric_brownian_motion(
    S0: float,
    mu: float,
    sigma: float,
    T: float,
    n_steps: int,
    n_simulations: int = 10000
) -> np.ndarray:
    """
    Simulate asset price paths using Geometric Brownian Motion.
    
    dS = μS dt + σS dW
    
    Parameters
    ----------
    S0 : float
        Initial price
    mu : float
        Drift (expected return, annualized)
    sigma : float
        Volatility (annualized)
    T : float
        Time horizon in years
    n_steps : int
        Number of time steps
    n_simulations : int
        Number of paths
        
    Returns
    -------
    np.ndarray
        Price paths, shape (n_simulations, n_steps + 1)
    """
    dt = T / n_steps
    paths = np.zeros((n_simulations, n_steps + 1))
    paths[:, 0] = S0
    
    for t in range(1, n_steps + 1):
        Z = np.random.standard_normal(n_simulations)
        paths[:, t] = paths[:, t-1] * np.exp(
            (mu - 0.5 * sigma**2) * dt + sigma * np.sqrt(dt) * Z
        )
    
    return paths


def monte_carlo_option_price(
    S0: float,
    K: float,
    r: float,
    sigma: float,
    T: float,
    option_type: str = 'call',
    n_simulations: int = 100000
) -> Tuple[float, float]:
    """
    Price European option using Monte Carlo simulation.
    
    Parameters
    ----------
    S0 : float
        Current stock price
    K : float
        Strike price
    r : float
        Risk-free rate (annualized)
    sigma : float
        Volatility (annualized)
    T : float
        Time to expiration (years)
    option_type : str
        'call' or 'put'
    n_simulations : int
        Number of simulations
        
    Returns
    -------
    Tuple[float, float]
        (option_price, standard_error)
    """
    # Simulate terminal stock prices
    Z = np.random.standard_normal(n_simulations)
    ST = S0 * np.exp((r - 0.5 * sigma**2) * T + sigma * np.sqrt(T) * Z)
    
    # Calculate payoffs
    if option_type.lower() == 'call':
        payoffs = np.maximum(ST - K, 0)
    else:
        payoffs = np.maximum(K - ST, 0)
    
    # Discount to present value
    option_price = np.exp(-r * T) * np.mean(payoffs)
    std_error = np.exp(-r * T) * np.std(payoffs) / np.sqrt(n_simulations)
    
    return option_price, std_error


# =============================================================================
# VALUE AT RISK (VaR)
# =============================================================================

def calculate_var(
    returns: np.ndarray,
    confidence_level: float = 0.95,
    investment: float = 10000,
    method: str = 'historical'
) -> float:
    """
    Calculate Value at Risk.
    
    Parameters
    ----------
    returns : np.ndarray
        Historical returns (daily)
    confidence_level : float
        VaR confidence level (e.g., 0.95 for 95%)
    investment : float
        Portfolio value
    method : str
        'historical' or 'parametric'
        
    Returns
    -------
    float
        VaR in currency units (positive number = potential loss)
    """
    if method == 'historical':
        var_pct = np.percentile(returns, (1 - confidence_level) * 100)
    else:  # parametric (assumes normal distribution)
        mu = np.mean(returns)
        sigma = np.std(returns)
        from scipy import stats
        var_pct = mu + sigma * stats.norm.ppf(1 - confidence_level)
    
    return -var_pct * investment


def monte_carlo_var(
    mu: float,
    sigma: float,
    investment: float = 10000,
    horizon_days: int = 1,
    confidence_level: float = 0.95,
    n_simulations: int = 10000
) -> float:
    """
    Calculate VaR using Monte Carlo simulation.
    
    Parameters
    ----------
    mu : float
        Expected daily return
    sigma : float
        Daily volatility
    investment : float
        Portfolio value
    horizon_days : int
        VaR time horizon
    confidence_level : float
        Confidence level
    n_simulations : int
        Number of simulations
        
    Returns
    -------
    float
        VaR in currency units
    """
    # Simulate returns over horizon
    simulated_returns = np.random.normal(
        mu * horizon_days,
        sigma * np.sqrt(horizon_days),
        n_simulations
    )
    
    # Calculate portfolio values
    portfolio_values = investment * (1 + simulated_returns)
    
    # VaR is the loss at the confidence percentile
    var_value = investment - np.percentile(portfolio_values, (1 - confidence_level) * 100)
    
    return var_value


# =============================================================================
# EXAMPLE USAGE
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("MONTE CARLO SIMULATION DEMO")
    print("=" * 60)
    
    # --- Test 1: Trading strategy simulation ---
    print("\n1. Trading Strategy Simulation")
    print("-" * 40)
    print("   Strategy: 55% win rate, 1.5:1 R/R, 100 trades")
    
    result = simulate_trades(
        win_rate=0.55,
        avg_win=1.5,
        avg_loss=1.0,
        n_trades=100,
        n_simulations=10000,
        initial_capital=10000,
        risk_per_trade=0.01
    )
    
    print(f"\n   Results (starting capital: €10,000):")
    print(f"   Expected final capital: €{result.mean:,.2f}")
    print(f"   Median final capital:   €{result.median:,.2f}")
    print(f"   95% CI: €{result.percentile_5:,.2f} - €{result.percentile_95:,.2f}")
    print(f"   Probability of profit:  {result.prob_above(10000)*100:.1f}%")
    print(f"   Probability of 50%+ gain: {result.prob_above(15000)*100:.1f}%")
    
    # --- Test 2: Risk of Ruin ---
    print("\n2. Risk of Ruin Analysis")
    print("-" * 40)
    
    ror = risk_of_ruin(
        win_rate=0.55,
        avg_win=1.5,
        avg_loss=1.0,
        risk_per_trade=0.02,
        ruin_threshold=0.5,
        n_trades=500
    )
    print(f"   Risk per trade: 2%")
    print(f"   Probability of 50% drawdown: {ror*100:.2f}%")
    
    ror_aggressive = risk_of_ruin(
        win_rate=0.55,
        avg_win=1.5,
        avg_loss=1.0,
        risk_per_trade=0.05,
        ruin_threshold=0.5,
        n_trades=500
    )
    print(f"\n   Risk per trade: 5% (aggressive)")
    print(f"   Probability of 50% drawdown: {ror_aggressive*100:.2f}%")
    
    # --- Test 3: Option Pricing ---
    print("\n3. European Call Option Pricing (Monte Carlo)")
    print("-" * 40)
    
    price, std_err = monte_carlo_option_price(
        S0=100,      # Stock price
        K=105,       # Strike
        r=0.05,      # Risk-free rate
        sigma=0.2,   # Volatility
        T=1.0,       # 1 year
        option_type='call',
        n_simulations=100000
    )
    
    print(f"   S0=€100, K=€105, r=5%, σ=20%, T=1 year")
    print(f"   Call option price: €{price:.4f}")
    print(f"   Standard error:    €{std_err:.4f}")
    print(f"   95% CI: €{price - 1.96*std_err:.4f} - €{price + 1.96*std_err:.4f}")
    
    # --- Test 4: VaR ---
    print("\n4. Value at Risk (Monte Carlo)")
    print("-" * 40)
    
    var_95 = monte_carlo_var(
        mu=0.0005,      # 0.05% daily expected return
        sigma=0.02,     # 2% daily volatility
        investment=100000,
        horizon_days=1,
        confidence_level=0.95
    )
    
    var_99 = monte_carlo_var(
        mu=0.0005,
        sigma=0.02,
        investment=100000,
        horizon_days=1,
        confidence_level=0.99
    )
    
    print(f"   Portfolio: €100,000")
    print(f"   Daily volatility: 2%")
    print(f"   1-day 95% VaR: €{var_95:,.2f}")
    print(f"   1-day 99% VaR: €{var_99:,.2f}")
    
    print("\n" + "=" * 60)
    print("All simulations completed!")
    print("=" * 60)
