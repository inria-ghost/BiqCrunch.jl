# BiqCrunch.jl
[BiqCrunch.jl](https://github.com/inria-ghost/BiqCrunch.jl) is a wrapper for
the [BiqCrunch](https://biqcrunch.lipn.univ-paris13.fr/) solver.

It requires access to a BiqCrunch binary. By default it assumes it installed at
`~/BiqCrunch/`. This can be changed by passing an argument to the optimizer
constructor or by setting the corresponding optimizer attribute.

```julia
model = BiqCrunch.Optimizer() # Default location

MOI.set(model, BiqCrunch.SolverBinary, "/path/to/biqcrunch_bin") # Change location

model2 = BiqCrunch.Optimizer("/path/to/other/biqcrunch_bin") # Or pass directly to constructor
```

## Installation
Install BiqCrunch.jl using the Julia package manager:
```julia
import Pkg
Pkg.add("BiqCrunch")
```
You will need to install the BiqCrunch solver separately.

## Use with JuMP


## MathOptInterface API
The BiqCrunch optimizer supports the following constraints and attributes.

List of supported objective functions:
* [`MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}`](@ref)
* [`MOI.ObjectiveFunction{MOI.ScalarQuadratic{Float64}}`](@ref)

List of supported variable types:
* [`MOI.Reals`](@ref)

List of supported constraint types:
* [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.LessThan{Float64}`](@ref)
* [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.GreaterThan{Float64}`](@ref)
* [`MOI.ScalarAffineFunction{Float64}`](@ref) in [`MOI.EqualTo{Float64}`](@ref)
* [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.LessThan{Float64}`](@ref)
* [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.GreaterThan{Float64}`](@ref)
* [`MOI.ScalarQuadraticFunction{Float64}`](@ref) in [`MOI.EqualTo{Float64}`](@ref)
* [`MOI.VariableIndex`](@ref) in [`MOI.ZeroOne`](@ref)
* [`MOI.VariableIndex`](@ref) in [`MOI.LessThan{Float64}`](@ref)
* [`MOI.VariableIndex`](@ref) in [`MOI.GreaterThan{Float64}`](@ref)
* [`MOI.VariableIndex`](@ref) in [`MOI.EqualTo{Float64}`](@ref)

List of supported model attributes:
* [`MOI.Name`](@ref)

List of supported optimizer attributes:
* [`BiqCrunch.SolverBinary`](@ref)
* [`BiqCrunch.ParameterFile`](@ref)
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

