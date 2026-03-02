import MathOptInterface as MOI

mutable struct _Solution
    input_file::String
    output_file::String
    param_file::String
    nodes::Int64
    rnode_bound::Float64
    obj_value::Int64
    variables::Vector{Int64}
    values::Dict{Int64,Int64}
    cpu_time::Float64
end

mutable struct Optimizer <: MOI.AbstractOptimizer
    # Optimizer attributes
    # AbsPaths to solver binary and parameter file
    bin::String
    paramfile::String

    # Model attributes
    name::String
    bcfile::String
    solution::_Solution

    function Optimizer(bin::String, paramfile::String)
        m = new()
        m.bin = bin
        m.paramfile = paramfile
        return m
    end

end

function MOI.empty!(model::Optimizer)
    model.name = ""
    model.bcfile = ""
    empty!(model.solution)
end

function MOI.is_empty(model::Optimizer)
    return isempty(name) && isempty(bcfile) && isempty(model.solution)
end

function Base.summary(io::IO, model::Optimizer)
    return print(
        io,
        "BiqCrunch with binary $(model.bin) and parameter file $(model.paramfile)",
    )
end

MOI.get(::Optimizer, ::MOI.SolverName) = "BiqCrunch"

MOI.get(::Optimizer, ::MOI.SolverVersion) = "v2.0.0"

MOI.get(model::Optimizer, ::MOI.RawSolver) = model

MOI.supports(::Optimizer, ::MOI.Name) = true

MOI.get(model::Optimizer, ::MOI.Name) = model.name

MOI.set(model::Optimizer, ::MOI.Name, name::String) = (model.name = name)

MOI.supports(::Optimizer, ::MOI.Silent) = false

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{MOI.ZeroOne},
)
    return true
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{<:Union{MOI.VariableIndex,MOI.ScalarAffineFunction,MOI.ScalarQuadraticFunction}},
    ::Type{<:Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}},
)
    return true
end

function _solve(bq_exe::String, bq_params::String, bcfile::String)
    @assert isfile(bq_exe)
    @assert isfile(bq_params)
    @assert isfile(bcfile)

    output = read(`$bq_exe $bcfile $bq_params`, String)
    re = r"""
    Output file:\s*(?<output_file>(/.+)+)
    Input file:\s*(?<input_file>(/.+)+)
    Parameter file:\s*(?<param_file>(/.+)+)
    (?s:.*?)
    Nodes = (?<nodes>\d+)
    Root node bound = (?<rnode_bound>\d+\.\d+)
    Maximum value = (?<obj_value>\d+)
    Solution = \{(?<sol>[[:digit:][:blank:]]+)\}
    CPU time = (?<cpu_time>\d+\.\d+) s
    """

    m = match(re, output)
    restults = nothing
    if m !== nothing
        results = _Solution(
            m["input_file"],
            m["output_file"],
            m["param_file"],
            parse(Int, m["nodes"]),
            parse(Float64, m["rnode_bound"]),
            parse(Int, m["obj_value"]),
            parse.(Int, split(m["sol"])),
            Dict(),
            parse(Float64, m["cpu_time"]),
        )
    else
        error("Regex matching failed on solver log output")
    end

    return results

end

function MOI.optimize!(model::Optimizer, src::MOI.ModelLike)
    model.bcfile = tempname()
    index_map = model2bc(src, model.bcfile)
    model.solution = _solve(model.bin, model.paramfile, model.bcfile)
    n = MOI.get(src, MOI.NumberOfVariables())
    (x -> model.solution.values[x] = 0).(1:n)
    (x -> model.solution.values[x] = 1).(model.solution.variables)

    return index_map, false
end

MOI.get(::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION

function MOI.get(m::Optimizer, ::MOI.PrimalStatus)
    if m.solution == nothing
        return MOI.NO_SOLUTION
    else
        return MOI.FEASIBLE_POINT
    end
end

MOI.get(::Optimizer, ::MOI.ResultCount) = 1

MOI.get(m::Optimizer, ::MOI.ObjectiveValue) = m.solution.obj_value

MOI.get(m::Optimizer, ::MOI.SolveTimeSec) = m.solution.cpu_time

MOI.get(m::Optimizer, ::MOI.VariablePrimal, v::MOI.VariableIndex) =
    m.solution.values[v.value]
