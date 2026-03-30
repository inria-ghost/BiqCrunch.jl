# BiqCrunch.jl
[BiqCrunch.jl](https://github.com/inria-ghost/BiqCrunch.jl) is a wrapper for
the [BiqCrunch](https://biqcrunch.lipn.univ-paris13.fr/) solver.

It requires access to a BiqCrunch binary. By default it assumes it installed at
`~/BiqCrunch/`. This can be changed by passing an argument to the optimizer
constructor or by setting the corresponding optimizer attribute.

```julia
model = BiqCrunch.Optimizer() # Default location

MOI.set(model, BiqCrunch.SolverBinary, "/path/to/biqcrunch_bin")

model2 = BiqCrunch.Optimizer("/path/to/other/biqcrunch_bin")
```
