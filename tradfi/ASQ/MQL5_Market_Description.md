# ASQ NeuralNet — MQL5 Market Description (Free Product)

---

## Product Name
ASQ NeuralNet — Neural Network Library for MQL5

## Short Description (max 200 chars)
Complete deep learning library in pure MQL5. Build, train and deploy neural networks natively in MetaTrader 5. No DLLs, no Python, no external APIs.

---

## Full Description (Market Listing)

ASQ NeuralNet is a complete neural network library written 100% in native MQL5 — no DLLs, no Python bridge, no external dependencies. Build, train, and run inference with multi-layer neural networks directly inside MetaTrader 5.

WHAT YOU GET

A fully functional deep learning framework for MQL5 developers, including:

— Dense matrix algebra engine with 40+ operations (multiply, transpose, Hadamard, He/Xavier initialization, NaN detection)
— 13 activation functions with analytical derivatives: ReLU, LeakyReLU, ELU, SELU, Sigmoid, Tanh, Softmax, Swish, Mish, GELU, Softplus, HardSigmoid, Linear
— Dense layers with forward and backward propagation, dropout, and gradient clipping
— 3 optimizers: SGD (with momentum), Adam, AdamW (decoupled weight decay)
— 7 learning rate schedulers: Constant, Step Decay, Exponential, Cosine Annealing, Linear, ReduceOnPlateau, Warmup, Cyclic LR
— 5 loss functions: MSE, MAE, Huber, Cross-Entropy, Binary Cross-Entropy
— Full training pipeline with mini-batch SGD, Fisher-Yates shuffle, and epoch logging

QUICK START

Building a network takes 6 lines of code:

   CNeuralNetwork net;
   net.Init(32);                        // 32 input features
   net.AddLayer(64, ACT_RELU);          // Hidden layer 1
   net.AddLayer(32, ACT_RELU, 0.2);     // Hidden layer 2 + dropout
   net.AddLayer(3, ACT_SOFTMAX);        // Output: BUY/SELL/HOLD
   net.Build();

Train with one call:

   net.SetOptimizer(OPT_ADAM, 0.001);
   net.SetLoss(LOSS_CROSS_ENTROPY);
   net.Fit(trainX, trainY, 100, 32);

Predict with one call:

   int action = net.PredictClass(features);   // 0=BUY, 1=SELL, 2=HOLD

USE CASES

— Train classification models for trading signals (BUY/SELL/HOLD)
— Price direction regression with MSE or Huber loss
— Pattern recognition on candlestick formations
— Market regime detection (trending / ranging / volatile)
— Feature importance analysis
— Q-value function approximation for reinforcement learning agents

PERFORMANCE

— Inference latency: < 0.1ms for typical architectures (under 1000 parameters)
— Memory: proportional to total parameters (5KB for a 32→64→32→3 network)
— No dynamic allocation during inference
— Numerically stable: NaN detection, gradient clipping, safe Softmax with max-subtraction

INSTALLATION

Place the 5 library files in MQL5/Include/AlgoSphere/NeuralNet/ and include the main header:

   #include <AlgoSphere/NeuralNet/NN_Network.mqh>

The demo script demonstrates matrix operations, activation functions, XOR classification, and synthetic market direction prediction.

LIBRARY FILES

— NN_Matrix.mqh (908 lines) — Dense matrix algebra engine
— NN_Activations.mqh (300 lines) — 13 activations + derivatives
— NN_Layer.mqh (374 lines) — Dense layer with forward/backward/dropout
— NN_Optimizer.mqh (454 lines) — SGD/Adam/AdamW + 7 LR schedulers
— NN_Network.mqh (734 lines) — Complete feedforward network with training
— ASQ_NeuralNet_Demo.mq5 (283 lines) — 4 runnable demonstrations

Total: 3,053 lines of pure MQL5.

TECHNICAL NOTES

— Weight initialization: He Init for ReLU-family, Xavier for Sigmoid/Tanh
— Box-Muller transform for normal distribution (MQL5 native MathRand)
— Softmax + Cross-Entropy gradient shortcut (ŷ - y, avoids full Jacobian)
— Inverted dropout (scaled during training, identity during inference)
— Fisher-Yates shuffle for mini-batch training
— Gradient norm clipping per layer (default max norm = 1.0)

Built by AlgoSphere Quant.

---

## Tags / Keywords
neural network, deep learning, machine learning, AI, MQL5, library, matrix, backpropagation, Adam optimizer, classification, regression, trading signals, pure MQL5, no DLL, feedforward, activation functions, softmax, cross-entropy, dropout

---

## Category
Libraries

## Type
Free

## MetaTrader Version
MetaTrader 5

---
