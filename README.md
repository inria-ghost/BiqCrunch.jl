# BiqCrunch.jl
[BiqCrunch.jl](https://github.com/inria-ghost/BiqCrunch.jl) is a wrapper for
the [BiqCrunch](https://biqcrunch.lipn.univ-paris13.fr/) solver.

This package depends on [BiqCrunch_jll]() for access to a solver binary, however
you can provide your own binary by passing the path to the constructor, or by
setting the appropriate optimizer attribute

```julia
model = BiqCrunch.Optimizer() # Uses BiqCrunch_jll

MOI.set(model, BiqCrunch.SolverBinary, "/path/to/biqcrunch_bin") # Change to custom binary

model2 = BiqCrunch.Optimizer("/path/to/other/biqcrunch_bin") # Pass path directly to constructor
```

## Installation
Install BiqCrunch.jl using the Julia package manager:
```julia
import Pkg
Pkg.add("BiqCrunch")
```

## Use with JuMP
```julia
using JuMP, BiqCrunch
model = Model(BiqCrunch.Optimizer)
# Or if you know beforehand the model only contains supported constraints
model = Model(BiqCrunch.Optimizer, add_bridges = false)

@variable(model, x[1:3], Bin)
@objective(model, Max, sum(x))
@constraint(model, x[1]*x[2] + x[3] == 1)

optimize!(model)
```

## MathOptInterface API
The BiqCrunch optimizer supports the following constraints and attributes.

List of supported objective functions:
* [`MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}`](@ref)
* [`MOI.ObjectiveFunction{MOI.ScalarQuadratic{Float64}}`](@ref)

List of supported constraint types:
* [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.LessThan{Float64}`](@ref)
* [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.GreaterThan{Float64}`](@ref)
* [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.EqualTo{Float64}`](@ref)
* [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.LessThan{Float64}`](@ref)
* [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.GreaterThan{Float64}`](@ref)
* [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.EqualTo{Float64}`](@ref)
* [`MOI.VariableIndex`](@ref) in [`MOI.ZeroOne`](@ref)

List of supported model attributes:
* [`MOI.Name`](@ref)
* [`MOI.ObjectiveSense`](@ref)

List of supported optimizer attributes:
* [`MOI.SolverName`](@ref)
* [`MOI.SolverVersion`](@ref)
* [`MOI.TimeLimitSec`](@ref)
* [`MOI.NodeLimit`](@ref)
* [`MOI.RelativeGapTolerance`](@ref)
* [`MOI.TerminationStatus`](@ref)
* [`MOI.RawStatusString`](@ref)
* [`MOI.ResultCount`](@ref)
* [`MOI.ObjectiveValue`](@ref)
* [`MOI.ObjectiveBound`](@ref)
* [`MOI.RelativeGap`](@ref)
* [`MOI.SolveTimeSec`](@ref)
* [`MOI.NodeCount`](@ref)

List of supported solver-specific attributes:
* [`BiqCrunch.SolverBinary`](@ref)
* [`BiqCrunch.ParameterFile`](@ref)
* [`BiqCrunch.Alpha0`](@ref)
* [`BiqCrunch.ScaleAlpha`](@ref)
* [`BiqCrunch.MinAlpha`](@ref)
* [`BiqCrunch.Tol0`](@ref)
* [`BiqCrunch.ScaleTol`](@ref)
* [`BiqCrunch.MinTol`](@ref)
* [`BiqCrunch.WithCuts`](@ref)
* [`BiqCrunch.GapCuts`](@ref)
* [`BiqCrunch.Cuts`](@ref)
* [`BiqCrunch.MinCuts`](@ref)
* [`BiqCrunch.Nitermax`](@ref)
* [`BiqCrunch.MinNiter`](@ref)
* [`BiqCrunch.MaxNiter`](@ref)
* [`BiqCrunch.Scaling`](@ref)
* [`BiqCrunch.Root`](@ref)
* [`BiqCrunch.Heur_1`](@ref)
* [`BiqCrunch.Heur_2`](@ref)
* [`BiqCrunch.Heur_3`](@ref)
* [`BiqCrunch.Soln_value_provided`](@ref)
* [`BiqCrunch.Soln_value`](@ref)
* [`BiqCrunch.Time_limit`](@ref)
* [`BiqCrunch.BranchingStrategy`](@ref)
* [`BiqCrunch.Seed`](@ref)
* [`BiqCrunch.Local_search`](@ref)
* [`BiqCrunch.NBGW1`](@ref)
* [`BiqCrunch.NBGW2`](@ref)

## Notes
* BiqCrunch only supports integer coefficients in the objective function
and in the constraints. Attempting to solve a model with fractional
coefficients will raise an [`FractionalCoefficient`](@ref) error.
* If getting a custom BiqCrunch parameter returns `nothing` then that parameter
is set to the default value of BiqCrunch. See [BiqCrunch's
documentation](https://biqcrunch.lipn.univ-paris13.fr/BiqCrunch/documentation)
for information on these parameters.

