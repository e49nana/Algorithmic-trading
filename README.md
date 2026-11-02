# pde-blocks

**Partial differential equations as generators of neural network architectures.**

Anwendungsprojekt (Modul 31.1) — B.Sc. Applied Mathematics & Physics, TH Nürnberg, WiSe 2026/27.
Supervisor: Prof. Dr. Elke Wilczok.

## Idea

A residual network computes `Y_{j+1} = Y_j + F(θ_j, Y_j)` — which is a forward Euler step for the ODE `∂_t Y = F(θ(t), Y)`. Reading the procedure backwards, one can start from a PDE and a numerical scheme with known properties, and derive a network block that inherits them: the stability condition of the scheme becomes a constraint on the learning rate and depth, symmetric filters halve the parameter count, multigrid becomes a U-Net.

This project builds a small PyTorch library in which one chooses a PDE and a scheme and obtains a block together with its stability condition, then benchmarks these blocks against standard ResNets.

## Literature

| Paper | Role |
|---|---|
| Alt, Schrader, Augustin, Peter, Weickert (2023), *Connections Between Numerical Algorithms for PDEs and Neural Networks*, JMIV 65 | methodological anchor — the "dictionary" scheme → block |
| Ruthotto, Haber (2020), *Deep Neural Networks Motivated by PDEs*, JMIV 62 | theoretical basis (stability theorems), template for experiments |
| Gu, Huang, Xu (2021), *PDEs is All You Need for Generating Neural Architectures*, arXiv:2103.08313 | historical entry point and motivation |

Reading notes live in [`literature/`](literature/).

## Status

| Phase | Dates | Status |
|---|---|---|
| 1 — Foundations: diffusion schemes, von Neumann stability, ResNets | 14.10 – 08.11 | 🔄 in progress |
| 2 — Library: `DiffusionBlock`, `SymResBlock`, activations, stability tool | 09.11 – 20.12 | planned |
| 3 — Experiments and theory | 04.01 – 22.01 | planned |
| 4 — Report and talk | by 12.02.2027 | planned |

Scope and schedule are to be confirmed with the supervisor.

## License

MIT
