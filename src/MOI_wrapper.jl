import MathOptInterface as MOI

mutable struct _Solution
    input_file::String
    output_file::String
    param_file::String
    nodes::Int64
    rnode_bound::Float64
    infeasible::Bool
    obj_value::Int64
    gap::Float64
    variables::Vector{Int64}
    values::Dict{Int64,Int64}
    cpu_time::Float64
end

function Base.:(==)(x::_Solution, y::_Solution)
    return x.input_file == y.input_file &&
           x.output_file == y.output_file &&
           x.param_file == y.param_file &&
           x.nodes == y.nodes &&
           x.rnode_bound == y.rnode_bound &&
           x.infeasible == y.infeasible &&
           x.obj_value == y.obj_value &&
           x.gap == y.gap &&
           x.variables == y.variables &&
           x.values == y.values &&
           x.cpu_time == y.cpu_time
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
    raw_output_string::String
    timelimit::Union{Nothing,Real}

    function Optimizer(bin::String, paramfile::String = "")
        m = new()
        m.bin = bin
        m.paramfile = paramfile
        if m.paramfile == ""
            m.paramfile = tempname()
            write(m.paramfile, "")
        end
        @assert isfile(m.paramfile)
        params = read(m.paramfile, String)
        tl_match = match(r"^\s*time_limit\s*=\s*(?<limit>(?:\d+\.\d+|\d+))"m, params)
        m.timelimit = (tl_match !== nothing) ? parse(Float64, tl_match[:limit]) : nothing
        return m
    end

end

function MOI.empty!(model::Optimizer)
    model.name = ""
    model.bcfile = ""
    model.raw_output_string = ""
    empty!(model.solution)
end

function MOI.is_empty(model::Optimizer)
    return isempty(model.name) &&
           isempty(model.bcfile) &&
           isempty(model.raw_output_string) &&
           isempty(model.solution)
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

MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

MOI.get(model::Optimizer, ::MOI.TimeLimitSec) = model.timelimit

function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, limit::Union{Nothing,Real})
    model.timelimit = limit
    params = read(model.paramfile, String)
    re = r"^\s*time_limit\s*=\s*\d+\.?\d*.*$"m

    if isnothing(limit)
        new_params = replace(params, re => "")
    else
        replacement = "time_limit = $limit"
        new_params = replace(params, re => replacement)
        if new_params == params
            prefix = (isempty(params) || endswith(params, '\n')) ? "" : "\n"
            new_params = params * prefix * replacement
        end
    end

    write(model.paramfile, new_params)

    return
end

# NOTE: should I add MOI.LessThan,MOI.GreatherThan,MOI.EqualTo ?
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

function _parse_solver_output(output::String)
    re = r"""
    Output\ file:\s*(?<output_file>.*)\n
    Input\ file:\s*(?<input_file>.*)\n
    Parameter\ file:\s*(?<param_file>.*)\n
    (?s:.*?) # Skips setup logs
    Nodes\ =\ (?<nodes>\d+)\n
    Root\ node\ bound\ =\ (?<rnode_bound>-?\d+\.\d+)\n
    (?:
        # Branch 1: Infeasible
        Problem\ is\ infeasible\.
        (?<status_infeasible>) # Empty capture to flag this branch
    |
        # Branch 2: Optimal
        (?:Maximum|Minimum)\ value\ =\ (?<obj_value>-?\d+)\n
        Solution\ =\ \{(?<sol>[[:digit:][:blank:]]+)\}
    |
        # Branch 3: Early Stop
        Best\ value\ =\ (?<best_value>-?\d+|inf)\n
        (?:Current\ bound\ =\ -?\d+\.\d+\n)?
        Gap\ =\ (?<gap>\d+\.\d+)%
    )
    \n\s*CPU\ time\ =\ (?<cpu_time>\d+\.\d+)\ s
    """x

    m = match(re, output)
    if m !== nothing
        results = _Solution(
            m["input_file"],
            m["output_file"],
            m["param_file"],
            parse(Int, m["nodes"]),
            parse(Float64, m["rnode_bound"]),
            m["status_infeasible"] !== nothing,
            parse(Int, something(m["obj_value"], m["best_value"], "0")),
            parse(Float64, something(m["gap"], "0.0")),
            parse.(Int, split(something(m["sol"], ""))),
            Dict(),
            parse(Float64, m["cpu_time"]),
        )
        return results
    else
        error("Regex matching failed on solver log output")
    end

end

function _solve(bq_exe::String, bq_params::String, bcfile::String)
    @assert isfile(bq_exe)
    @assert isfile(bq_params)
    @assert isfile(bcfile)

    output = read(`$bq_exe $bcfile $bq_params`, String)
    results = _parse_solver_output(output)

    return results, output

end

function MOI.optimize!(model::Optimizer, src::MOI.ModelLike)
    model.bcfile = tempname()
    index_map = model2bc(src, model.bcfile)
    model.solution, model.raw_output_string =
        _solve(model.bin, model.paramfile, model.bcfile)
    n = MOI.get(src, MOI.NumberOfVariables())
    (x -> model.solution.values[x] = 0).(1:n)
    (x -> model.solution.values[x] = 1).(model.solution.variables)

    return index_map, false
end

MOI.get(::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION

function MOI.get(m::Optimizer, ::MOI.PrimalStatus)
    if m.solution == nothing || m.solution.infeasible || m.solution.gap !== 0.0
        return MOI.NO_SOLUTION
    else
        return MOI.FEASIBLE_POINT
    end
end

MOI.get(m::Optimizer, ::MOI.RawStatusString) = m.raw_output_string

function MOI.get(m::Optimizer, ::MOI.TerminationStatus)
    if m.solution == nothing
        return MOI.OPTIMIZE_NOT_CALLED
    elseif m.solution.infeasible
        return MOI.INFEASIBLE
    elseif m.solution.gap == 0.0
        return MOI.OPTIMAL
    elseif m.solution.gap != 0.0 && m.timelimit != nothing
        return MOI.TIME_LIMIT
    else
        return MOI.OTHER_ERROR
    end
end

MOI.get(::Optimizer, ::MOI.ResultCount) = 1

MOI.get(m::Optimizer, ::MOI.ObjectiveValue) = m.solution.obj_value

MOI.get(m::Optimizer, ::MOI.SolveTimeSec) = m.solution.cpu_time

MOI.get(m::Optimizer, ::MOI.VariablePrimal, v::MOI.VariableIndex) =
    m.solution.values[v.value]

MOI.get(m::Optimizer, ::MOI.NodeCount) = m.solution.nodes
