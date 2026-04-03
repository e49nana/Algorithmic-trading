# ASQ NeuralNet — MQL5 Code Base Description

---

## Title
ASQ NeuralNet — Pure MQL5 Neural Network Library

## Category
Libraries

## Description (Code Base listing)

Complete deep learning library written entirely in native MQL5. Build, train, and deploy feedforward neural networks inside MetaTrader 5 with zero external dependencies.

Features:
— Matrix algebra engine (40+ operations, He/Xavier init, NaN safety)
— 13 activation functions with analytical derivatives (ReLU, Sigmoid, Tanh, Softmax, Swish, Mish, GELU, and more)
— Dense layers with forward/backward propagation and dropout
— 3 optimizers: SGD (momentum), Adam, AdamW
— 7 learning rate schedulers (Cosine Annealing, Cyclic LR, Warmup, etc.)
— 5 loss functions: MSE, MAE, Huber, Cross-Entropy, Binary CE
— Mini-batch training with Fisher-Yates shuffle

Quick start — 6 lines to build a network:

   #include <AlgoSphere/NeuralNet/NN_Network.mqh>

   CNeuralNetwork net;
   net.Init(32);
   net.AddLayer(64, ACT_RELU);
   net.AddLayer(3, ACT_SOFTMAX);
   net.Build();
   net.SetOptimizer(OPT_ADAM, 0.001);

Train: net.Fit(X, Y, 100, 32);
Predict: int cls = net.PredictClass(features);

5 library files (2,770 lines) + 1 demo script (283 lines).
Install in MQL5/Include/AlgoSphere/NeuralNet/.

Built by AlgoSphere Quant.

---

## Submission Notes

For Code Base, submit each file individually:

1. NN_Matrix.mqh — Category: Libraries
2. NN_Activations.mqh — Category: Libraries
3. NN_Layer.mqh — Category: Libraries
4. NN_Optimizer.mqh — Category: Libraries
5. NN_Network.mqh — Category: Libraries
6. ASQ_NeuralNet_Demo.mq5 — Category: Scripts

OR submit the demo script as the main entry with the library files as dependencies noted in the description.

Recommended approach: Submit the demo script (ASQ_NeuralNet_Demo.mq5) as a single Code Base entry with all 5 .mqh files included. The Code Base allows attaching multiple files to one submission.

---
