import MathOptInterface as MOI
import BiqCrunch_jll

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

struct SolverBinary <: MOI.AbstractOptimizerAttribute end
struct ParameterFile <: MOI.AbstractOptimizerAttribute end

mutable struct Optimizer <: MOI.AbstractOptimizer
    # Optimizer attributes
    # AbsPaths to solver binary and parameter file
    bin::Function
    paramfile::String

    # model attributes
    name::String
    bcfile::String
    solution::Union{Nothing,_Solution}
    raw_output_string::String
    timelimit::Union{Nothing,Real}
    nodelimit::Union{Nothing,Int}
    relgaptol::Union{Nothing,Float64}

    function Optimizer(bin::String = "", paramfile::String = "")
        m = new()
        if bin == ""
            m.bin = BiqCrunch_jll.generic_bq
        else
            m.bin = () -> Cmd(`$bin`)
        end
        m.paramfile = paramfile
        if m.paramfile == ""
            m.paramfile = tempname()
            write(m.paramfile, "")
        end

        _parse_params(m)

        m.name = ""
        m.bcfile = ""
        m.solution = nothing
        m.raw_output_string = ""
        return m
    end

end

function _parse_param(param, param_t, params_string)
    pattern = Regex("^\\s*$param\\s*=\\s*(?<value>(?:\\d+\\.\\d+|\\d+))", "m")
    r_match = match(pattern, params_string)
    return (r_match !== nothing) ? parse(param_t, r_match[:value]) : nothing
end

function _parse_params(m::Optimizer)
    @assert isfile(m.paramfile)
    params = read(m.paramfile, String)
    m.timelimit = _parse_param("time_limit", Float64, params)
    m.nodelimit = _parse_param("node_limit", Int, params)
    m.relgaptol = _parse_param("relative_gap_tol", Float64, params)
end

function MOI.empty!(m::Optimizer)
    m.name = ""
    m.bcfile = ""
    m.raw_output_string = ""
    m.solution = nothing
    m.paramfile = tempname()
    write(m.paramfile, "")
    _parse_params(m)
end

function MOI.is_empty(m::Optimizer)
    return isempty(m.name) &&
           isempty(m.bcfile) &&
           isempty(m.raw_output_string) &&
           m.solution == nothing
end

function Base.summary(io::IO, m::Optimizer)
    return print(io, "BiqCrunch with binary $(m.bin) and parameter file $(m.paramfile)")
end

MOI.get(::Optimizer, ::MOI.SolverName) = "BiqCrunch"

MOI.get(::Optimizer, ::MOI.SolverVersion) = "v2.0.0"

MOI.get(m::Optimizer, ::MOI.RawSolver) = m

MOI.supports(::Optimizer, ::MOI.Name) = true

MOI.get(m::Optimizer, ::MOI.Name) = m.name

MOI.set(m::Optimizer, ::MOI.Name, name::String) = (m.name = name)

function _set_param(m::Optimizer, param, value)
    params = read(m.paramfile, String)
    re = Regex("^\\s*$param\\s*=\\s*\\d+\\.?\\d*.*\$", "m")

    if isnothing(value)
        new_params = replace(params, re => "")
    else
        replacement = "$param = $value"
        new_params = replace(params, re => replacement)
        if new_params == params
            prefix = (isempty(params) || endswith(params, '\n')) ? "" : "\n"
            new_params = params * prefix * replacement
        end
    end

    write(m.paramfile, new_params)
end

MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

MOI.get(m::Optimizer, ::MOI.TimeLimitSec) = m.timelimit

function MOI.set(m::Optimizer, ::MOI.TimeLimitSec, limit::Union{Nothing,Real})
    m.timelimit = limit
    _set_param(m, "time_limit", limit)
    return
end

MOI.supports(::Optimizer, ::MOI.NodeLimit) = true

MOI.get(m::Optimizer, ::MOI.NodeLimit) = m.nodelimit

function MOI.set(m::Optimizer, ::MOI.NodeLimit, limit::Union{Nothing,Int})
    m.nodelimit = limit
    _set_param(m, "node_limit", limit)
    return
end

MOI.supports(::Optimizer, ::MOI.RelativeGapTolerance) = true

MOI.get(m::Optimizer, ::MOI.RelativeGapTolerance) = m.relgaptol

function MOI.set(m::Optimizer, ::MOI.RelativeGapTolerance, limit::Union{Nothing,Float64})
    m.relgaptol = limit
    _set_param(m, "relative_gap_tol", limit)
    return
end

MOI.supports(::Optimizer, ::MOI.Silent) = false
MOI.supports(::Optimizer, ::MOI.ObjectiveLimit) = false
MOI.supports(::Optimizer, ::MOI.SolutionLimit) = false
MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = false
MOI.supports(::Optimizer, ::MOI.NumberOfThreads) = false
MOI.supports(::Optimizer, ::MOI.AbsoluteGapTolerance) = false

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
    ::Type{<:Union{MOI.LessThan{Float64},MOI.GreaterThan{Float64},MOI.EqualTo{Float64}}},
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

function _solve(bq_exe::Function, bq_params::String, bcfile::String)
    @assert isfile(bq_params)
    @assert isfile(bcfile)

    output = read(`$(bq_exe()) $bcfile $bq_params`, String)
    results = _parse_solver_output(output)

    return results, output

end

function MOI.optimize!(m::Optimizer, src::MOI.ModelLike)
    m.bcfile = tempname()
    index_map, bcmodel = model2bc(src)
    write(m.bcfile, bcmodel)
    m.solution, m.raw_output_string = _solve(m.bin, m.paramfile, m.bcfile)
    n = length(index_map) # MOI.get(src, MOI.NumberOfVariables())
    (x -> m.solution.values[x] = 0).(1:n)
    (x -> m.solution.values[x] = 1).(m.solution.variables)

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
    elseif m.solution.gap != 0.0 && m.solution.cpu_time >= something(m.timelimit, Inf)
        return MOI.TIME_LIMIT
    elseif m.solution.gap != 0.0 && m.solution.nodes >= something(m.nodelimit, Inf)
        return MOI.NODE_LIMIT
    elseif m.solution.gap != 0.0 && m.solution.gap < something(m.relgaptol, 0.0)
        return MOI.ALMOST_OPTIMAL
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

MOI.get(m::Optimizer, ::MOI.ObjectiveBound) = m.solution.rnode_bound

MOI.get(m::Optimizer, ::MOI.RelativeGap) = m.solution.gap

# Solver-specific attributes
function MOI.set(m::Optimizer, ::SolverBinary, bin::String)
    m.bin = Cmd(`$bin`)
    return
end

function MOI.get(model::Optimizer, ::SolverBinary)
    return m.bin
end

function MOI.set(m::Optimizer, ::ParameterFile, file::String)
    m.paramfile = file
    _parse_params(m)
    return
end

function MOI.get(model::Optimizer, ::ParameterFile)
    return m.paramfile
end
