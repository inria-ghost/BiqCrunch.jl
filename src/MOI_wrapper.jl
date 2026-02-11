import MathOptInterface as MOI

# NOTE: Assumes BiqCrunch is installed in the home directory

struct Optimizer <: MOI.AbstractOptimizer
    # Optimizer attributes
    # AbsPaths to solver binary and parameter file
    bin::String
    paramfile::String
    silent::Bool

    # Model attributes
    name::String
    bcfile::String
    variables::Dict{String,Int}
    objective_value::Float64

    function Optimizer()
        m = new()
        m.bin = expanduser("~/BiqCrunch/problems/generic/biqcrunch")
        m.paramfile = expanduser("~/BiqCrunch/problems/generic/biq_crunch.param")
        m.silent = false

        MOI.empty!(m)
        return m
    end

end

function MOI.empty!(model::Optimizer)
    name = ""
    bcfile = ""
    empty!(model.variables)
    model.objective_value = 0.0
end

function MOI.is_empty(model::Optimizer)
    return isempty(name) && isempty(bcfile) && isempty(model.variables)
end

function Base.summary(io::IO, model::Optimizer)
    return print(io, "BiqCrunch with the pointer $(model.ptr)")
end

MOI.get(::Optimizer, ::MOI.SolverName) = "BiqCrunch"

MOI.get(::Optimizer, ::MOI.SolverVersion) = "v2.0.0"

MOI.get(model::Optimizer, ::MOI.RawSolver) = model

MOI.supports(::Optimizer, ::MOI.Name) = true

MOI.get(model::Optimizer, ::MOI.Name) = model.name

MOI.set(model::Optimizer, ::MOI.Name, name::String) = (model.name = name)

MOI.supports(::Optimizer, ::MOI.Silent) = true

MOI.get(model::Optimizer, ::MOI.Silent) = model.silent

MOI.set(model::Optimizer, ::MOI.Silent, flag::Bool) = (model.silent = flag)

function MOI.optimize!(model::Optimizer, src::MOI.ModelLike)
    model.bcfile = tempname()
    model2bc(src, model.bcfile)

end
