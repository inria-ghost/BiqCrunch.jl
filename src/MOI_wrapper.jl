import MathOptInterface as MOI
import BiqCrunch_jll

mutable struct _Solution
    input_file::String
    output_file::String
    param_file::String
    nodes::Int64
    rnode_bound::Float64
    infeasible::Bool
    obj_value::Float64
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
    time_limit::Union{Nothing,Real}
    node_limit::Union{Nothing,Int}
    relative_gap_tol::Union{Nothing,Float64}

    # BiqCrunch parameters
    alpha0::Union{Nothing,Float64}
    scaleAlpha::Union{Nothing,Float64}
    minAlpha::Union{Nothing,Float64}
    tol0::Union{Nothing,Float64}
    scaleTol::Union{Nothing,Float64}
    minTol::Union{Nothing,Float64}
    withCuts::Union{Nothing,Int}
    gapCuts::Union{Nothing,Float64}
    cuts::Union{Nothing,Int}
    minCuts::Union{Nothing,Int}
    nitermax::Union{Nothing,Int}
    minNiter::Union{Nothing,Int}
    maxNiter::Union{Nothing,Int}
    scaling::Union{Nothing,Int}
    root::Union{Nothing,Int}
    heur_1::Union{Nothing,Int}
    heur_2::Union{Nothing,Int}
    heur_3::Union{Nothing,Int}
    soln_value_provided::Union{Nothing,Int}
    soln_value::Union{Nothing,Int}
    branchingStrategy::Union{Nothing,Int}
    seed::Union{Nothing,Int}
    local_search::Union{Nothing,Int}
    NBGW1::Union{Nothing,Int}
    NBGW2::Union{Nothing,Int}

    function Optimizer(bin::String="", paramfile::String="")
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
    m.time_limit = _parse_param("time_limit", Float64, params)
    m.node_limit = _parse_param("node_limit", Int, params)
    m.relative_gap_tol = _parse_param("relative_gap_tol", Float64, params)

    m.alpha0 = _parse_param("alpha0", Float64, params)
    m.scaleAlpha = _parse_param("scaleAlpha", Float64, params)
    m.minAlpha = _parse_param("minAlpha", Float64, params)
    m.tol0 = _parse_param("tol0", Float64, params)
    m.scaleTol = _parse_param("scaleTol", Float64, params)
    m.minTol = _parse_param("minTol", Float64, params)
    m.withCuts = _parse_param("withCuts", Int, params)
    m.gapCuts = _parse_param("gapCuts", Float64, params)
    m.cuts = _parse_param("cuts", Int, params)
    m.minCuts = _parse_param("minCuts", Int, params)
    m.nitermax = _parse_param("nitermax", Int, params)
    m.minNiter = _parse_param("minNiter", Int, params)
    m.maxNiter = _parse_param("maxNiter", Int, params)
    m.scaling = _parse_param("scaling", Int, params)
    m.root = _parse_param("root", Int, params)
    m.heur_1 = _parse_param("heur_1", Int, params)
    m.heur_2 = _parse_param("heur_2", Int, params)
    m.heur_3 = _parse_param("heur_3", Int, params)
    m.soln_value_provided = _parse_param("soln_value_provided", Int, params)
    m.soln_value = _parse_param("soln_value", Int, params)
    m.branchingStrategy = _parse_param("branchingStrategy", Int, params)
    m.seed = _parse_param("seed", Int, params)
    m.local_search = _parse_param("local_search", Int, params)
    m.NBGW1 = _parse_param("NBGW1", Int, params)
    m.NBGW2 = _parse_param("NBGW2", Int, params)
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
           isnothing(m.solution)
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

MOI.get(m::Optimizer, ::MOI.TimeLimitSec) = m.time_limit

function MOI.set(m::Optimizer, ::MOI.TimeLimitSec, limit::Union{Nothing,Real})
    m.time_limit = limit
    _set_param(m, "time_limit", limit)
    return
end

MOI.supports(::Optimizer, ::MOI.NodeLimit) = true

MOI.get(m::Optimizer, ::MOI.NodeLimit) = m.node_limit

function MOI.set(m::Optimizer, ::MOI.NodeLimit, limit::Union{Nothing,Int})
    m.node_limit = limit
    _set_param(m, "node_limit", limit)
    return
end

MOI.supports(::Optimizer, ::MOI.RelativeGapTolerance) = true

MOI.get(m::Optimizer, ::MOI.RelativeGapTolerance) = m.relative_gap_tol

function MOI.set(m::Optimizer, ::MOI.RelativeGapTolerance, limit::Union{Nothing,Float64})
    m.relative_gap_tol = limit
    _set_param(m, "relative_gap_tol", limit)
    return
end

MOI.supports(::Optimizer, ::MOI.Silent) = false
MOI.supports(::Optimizer, ::MOI.ObjectiveLimit) = false
MOI.supports(::Optimizer, ::MOI.SolutionLimit) = false
MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = false
MOI.supports(::Optimizer, ::MOI.NumberOfThreads) = false
MOI.supports(::Optimizer, ::MOI.AbsoluteGapTolerance) = false

function MOI.supports(
    ::Optimizer,
    ::Union{
        MOI.ObjectiveSense,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}},
        MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}},
    },
)
    return true
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VariableIndex},
    ::Type{MOI.ZeroOne},
)
    return true
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{<:Union{MOI.ScalarAffineFunction,MOI.ScalarQuadraticFunction}},
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
            parse(Float64, something(m["obj_value"], m["best_value"], "0")),
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
    MOI.set(m, MOI.Name(), MOI.get(src, MOI.Name()))

    if isempty(MOI.get(src, MOI.ListOfVariableIndices()))
        index_map, bcmodel = model2bc(src)
        m.solution = _Solution(
            "",
            "",
            m.paramfile,
            0,
            0.0,
            false,
            0,
            0.0,
            [],
            Dict(),
            0.0,
        )
    else
        m.bcfile = tempname()
        index_map, bcmodel = model2bc(src)
        write(m.bcfile, bcmodel)
        m.solution, m.raw_output_string = _solve(m.bin, m.paramfile, m.bcfile)
        if MOI.get(src, MOI.ObjectiveSense()) != MOI.FEASIBILITY_SENSE
            obj_fun_type = MOI.get(src, MOI.ObjectiveFunctionType())
            m.solution.obj_value += MOI.constant(MOI.get(src, MOI.ObjectiveFunction{obj_fun_type}()))
        end
        n = length(index_map) # MOI.get(src, MOI.NumberOfVariables())
        (x -> m.solution.values[x] = 0).(1:n)
        (x -> m.solution.values[x] = 1).(m.solution.variables)
    end

    return index_map, false
end

MOI.get(::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION

function MOI.get(m::Optimizer, ::MOI.PrimalStatus)
    if isnothing(m.solution) || m.solution.infeasible || m.solution.gap !== 0.0
        return MOI.NO_SOLUTION
    else
        return MOI.FEASIBLE_POINT
    end
end

MOI.get(m::Optimizer, ::MOI.RawStatusString) = m.raw_output_string

function MOI.get(m::Optimizer, ::MOI.TerminationStatus)
    if isnothing(m.solution)
        return MOI.OPTIMIZE_NOT_CALLED
    elseif m.solution.infeasible
        return MOI.INFEASIBLE
    elseif m.solution.gap == 0.0
        return MOI.OPTIMAL
    elseif m.solution.gap != 0.0 && m.solution.cpu_time >= something(m.time_limit, Inf)
        return MOI.TIME_LIMIT
    elseif m.solution.gap != 0.0 && m.solution.nodes >= something(m.node_limit, Inf)
        return MOI.NODE_LIMIT
    elseif m.solution.gap != 0.0 && m.solution.gap < something(m.relative_gap_tol, 0.0)
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

function MOI.get(m::Optimizer, ::SolverBinary)
    return m.bin
end

function MOI.set(m::Optimizer, ::ParameterFile, file::String)
    m.paramfile = file
    _parse_params(m)
    return
end

function MOI.get(m::Optimizer, ::ParameterFile)
    return m.paramfile
end

# BiqCrunch parameters
struct Alpha0 <: MOI.AbstractOptimizerAttribute end
struct ScaleAlpha <: MOI.AbstractOptimizerAttribute end
struct MinAlpha <: MOI.AbstractOptimizerAttribute end
struct Tol0 <: MOI.AbstractOptimizerAttribute end
struct ScaleTol <: MOI.AbstractOptimizerAttribute end
struct MinTol <: MOI.AbstractOptimizerAttribute end
struct WithCuts <: MOI.AbstractOptimizerAttribute end
struct GapCuts <: MOI.AbstractOptimizerAttribute end
struct Cuts <: MOI.AbstractOptimizerAttribute end
struct MinCuts <: MOI.AbstractOptimizerAttribute end
struct Nitermax <: MOI.AbstractOptimizerAttribute end
struct MinNiter <: MOI.AbstractOptimizerAttribute end
struct MaxNiter <: MOI.AbstractOptimizerAttribute end
struct Scaling <: MOI.AbstractOptimizerAttribute end
struct Root <: MOI.AbstractOptimizerAttribute end
struct Heur_1 <: MOI.AbstractOptimizerAttribute end
struct Heur_2 <: MOI.AbstractOptimizerAttribute end
struct Heur_3 <: MOI.AbstractOptimizerAttribute end
struct Soln_value_provided <: MOI.AbstractOptimizerAttribute end
struct Soln_value <: MOI.AbstractOptimizerAttribute end
struct Time_limit <: MOI.AbstractOptimizerAttribute end
struct BranchingStrategy <: MOI.AbstractOptimizerAttribute end
struct Seed <: MOI.AbstractOptimizerAttribute end
struct Local_search <: MOI.AbstractOptimizerAttribute end
struct NBGW1 <: MOI.AbstractOptimizerAttribute end
struct NBGW2 <: MOI.AbstractOptimizerAttribute end

macro generate_setter(param, attribute, value_type)
    return :(function MOI.set(m::Optimizer, $attribute, value::$value_type)
        setproperty!(m, $param, value)
        _set_param(m, "$($param)", value)
    end)
end

@generate_setter(:alpha0, ::Alpha0, Union{Nothing,Float64})
@generate_setter(:scaleAlpha, ::ScaleAlpha, Union{Nothing,Float64})
@generate_setter(:minAlpha, ::MinAlpha, Union{Nothing,Float64})
@generate_setter(:tol0, ::Tol0, Union{Nothing,Float64})
@generate_setter(:scaleTol, ::ScaleTol, Union{Nothing,Float64})
@generate_setter(:minTol, ::MinTol, Union{Nothing,Float64})
@generate_setter(:withCuts, ::WithCuts, Union{Nothing,Int})
@generate_setter(:gapCuts, ::GapCuts, Union{Nothing,Float64})
@generate_setter(:cuts, ::Cuts, Union{Nothing,Int})
@generate_setter(:minCuts, ::MinCuts, Union{Nothing,Int})
@generate_setter(:nitermax, ::Nitermax, Union{Nothing,Int})
@generate_setter(:minNiter, ::MinNiter, Union{Nothing,Int})
@generate_setter(:maxNiter, ::MaxNiter, Union{Nothing,Int})
@generate_setter(:scaling, ::Scaling, Union{Nothing,Int})
@generate_setter(:root, ::Root, Union{Nothing,Int})
@generate_setter(:heur_1, ::Heur_1, Union{Nothing,Int})
@generate_setter(:heur_2, ::Heur_2, Union{Nothing,Int})
@generate_setter(:heur_3, ::Heur_3, Union{Nothing,Int})
@generate_setter(:soln_value_provided, ::Soln_value_provided, Union{Nothing,Int})
@generate_setter(:soln_value, ::Soln_value, Union{Nothing,Int})
@generate_setter(:branchingStrategy, ::BranchingStrategy, Union{Nothing,Int})
@generate_setter(:seed, ::Seed, Union{Nothing,Int})
@generate_setter(:local_search, ::Local_search, Union{Nothing,Int})
@generate_setter(:NBGW1, ::NBGW1, Union{Nothing,Int})
@generate_setter(:NBGW2, ::NBGW2, Union{Nothing,Int})

MOI.get(m::Optimizer, ::Alpha0) = m.alpha0
MOI.get(m::Optimizer, ::ScaleAlpha) = m.scaleAlpha
MOI.get(m::Optimizer, ::MinAlpha) = m.minAlpha
MOI.get(m::Optimizer, ::Tol0) = m.tol0
MOI.get(m::Optimizer, ::ScaleTol) = m.scaleTol
MOI.get(m::Optimizer, ::MinTol) = m.minTol
MOI.get(m::Optimizer, ::WithCuts) = m.withCuts
MOI.get(m::Optimizer, ::GapCuts) = m.gapCuts
MOI.get(m::Optimizer, ::Cuts) = m.cuts
MOI.get(m::Optimizer, ::MinCuts) = m.minCuts
MOI.get(m::Optimizer, ::Nitermax) = m.nitermax
MOI.get(m::Optimizer, ::MinNiter) = m.minNiter
MOI.get(m::Optimizer, ::MaxNiter) = m.maxNiter
MOI.get(m::Optimizer, ::Scaling) = m.scaling
MOI.get(m::Optimizer, ::Root) = m.root
MOI.get(m::Optimizer, ::Heur_1) = m.heur_1
MOI.get(m::Optimizer, ::Heur_2) = m.heur_2
MOI.get(m::Optimizer, ::Heur_3) = m.heur_3
MOI.get(m::Optimizer, ::Soln_value_provided) = m.soln_value_provided
MOI.get(m::Optimizer, ::Soln_value) = m.soln_value
MOI.get(m::Optimizer, ::Time_limit) = m.time_limit
MOI.get(m::Optimizer, ::BranchingStrategy) = m.branchingStrategy
MOI.get(m::Optimizer, ::Seed) = m.seed
MOI.get(m::Optimizer, ::Local_search) = m.local_search
MOI.get(m::Optimizer, ::NBGW1) = m.NBGW1
MOI.get(m::Optimizer, ::NBGW2) = m.NBGW2
