# ASQ NeuralNet — Pure MQL5 Neural Network Library

**Author:** AlgoSphere Quant ([robin2.0](https://www.mql5.com/en/users/robin2.0))
**Version:** 1.0
**License:** MIT — Free for commercial and personal use
**Platform:** MetaTrader 5 (Build 3000+)
**Dependencies:** None (100% native MQL5)

---

## What Is This?

ASQ NeuralNet is a complete deep learning library written entirely in MQL5. No Python, no DLLs, no external APIs — everything runs natively inside MetaTrader 5.

Build, train, and deploy neural networks for classification, regression, and trading signal generation directly in your Expert Advisors and indicators.

---

## Features

**Matrix Engine** — Row-major dense matrix with 40+ operations: multiply, transpose, Hadamard, He/Xavier initialization, NaN detection, Frobenius norm.

**13 Activation Functions** — ReLU, LeakyReLU, ELU, SELU, Sigmoid, Tanh, Softmax, Swish, Mish, GELU, Softplus, HardSigmoid, Linear. All with analytical derivatives for backpropagation.

**Dense Layers** — Forward and backward pass, dropout (inverted, training-mode only), gradient clipping, automatic He/Xavier weight initialization.

**3 Optimizers** — SGD (with momentum), Adam, AdamW (decoupled weight decay).

**7 Learning Rate Schedulers** — Constant, Step Decay, Exponential, Cosine Annealing, Linear, ReduceOnPlateau, Warmup, Cyclic LR.

**5 Loss Functions** — MSE, MAE, Huber (Smooth L1), Cross-Entropy, Binary Cross-Entropy. Softmax+CE gradient shortcut included.

**Full Training Pipeline** — `Fit()` with mini-batch SGD, Fisher-Yates shuffle, NaN detection, epoch logging.

---

## Installation

Copy the library files into your MetaTrader 5 data folder:

```
MQL5/
├── Include/
│   └── AlgoSphere/
│       └── NeuralNet/
│           ├── NN_Matrix.mqh
│           ├── NN_Activations.mqh
│           ├── NN_Layer.mqh
│           ├── NN_Optimizer.mqh
│           └── NN_Network.mqh
└── Scripts/
    └── AlgoSphere/
        └── ASQ_NeuralNet_Demo.mq5
```

---

## Quick Start

```mql5
#include <AlgoSphere/NeuralNet/NN_Network.mqh>

// 1. Build network
CNeuralNetwork net;
net.Init(32);                        // 32 input features
net.AddLayer(64, ACT_RELU);          // Hidden layer 1
net.AddLayer(32, ACT_RELU, 0.2);     // Hidden layer 2 + 20% dropout
net.AddLayer(3, ACT_SOFTMAX);        // Output: BUY / SELL / HOLD
net.Build();

// 2. Configure
net.SetOptimizer(OPT_ADAM, 0.001);
net.SetLoss(LOSS_CROSS_ENTROPY);

// 3. Train
net.Fit(trainX, trainY, 100, 32);    // 100 epochs, batch size 32

// 4. Predict
double features[], output[];
// ... fill features from market data ...
net.Predict(features, output);       // output = [P(BUY), P(SELL), P(HOLD)]
int action = net.PredictClass(features);  // 0=BUY, 1=SELL, 2=HOLD
```

---

## Use Cases

- **Trading Signal Classification** — Train on labeled market data (BUY/SELL/HOLD) using technical indicators as features
- **Price Direction Regression** — Predict future returns with MSE loss
- **Pattern Recognition** — Detect candlestick patterns, chart formations
- **Sentiment Scoring** — Score market regimes (trending / ranging / volatile)
- **Feature Importance** — Analyze which indicators contribute most to predictions
- **Q-Value Approximation** — Use as the function approximator in a DQN reinforcement learning agent

---

## Architecture Notes

The library is designed for trading latency:
- All matrices are flat `double[]` arrays (no dynamic allocation per inference)
- Inference time: < 0.1ms for typical architectures (< 1000 params)
- Memory: proportional to total parameters (e.g., 32→64→32→3 ≈ 5KB)

Weight initialization follows best practices:
- **He Init** for ReLU-family activations
- **Xavier Init** for Sigmoid/Tanh
- Box-Muller for normal distribution

---

## File Reference

| File | Lines | Role |
|------|-------|------|
| `NN_Matrix.mqh` | ~650 | Dense matrix algebra engine |
| `NN_Activations.mqh` | ~350 | 13 activation functions + derivatives |
| `NN_Layer.mqh` | ~300 | Dense layer (forward/backward/dropout) |
| `NN_Optimizer.mqh` | ~380 | SGD/Adam/AdamW + 7 LR schedulers |
| `NN_Network.mqh` | ~500 | Complete feedforward network |
| **Total** | **~2,180** | **Zero external dependencies** |

---

---

*Built by AlgoSphere Quant — [robin2.0 on MQL5](https://www.mql5.com/en/users/robin2.0)*
