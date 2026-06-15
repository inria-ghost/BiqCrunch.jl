module BiqCrunch

import MathOptInterface as MOI

struct VariableNotBinary <: MOI.UnsupportedError
    vi::MOI.VariableIndex
end

function Base.showerror(io::IO, err::VariableNotBinary)
    print(io,
        "Variable $(err.vi) must be constrained to MOI.ZeroOne.")
end

struct FractionalCoefficient <: MOI.UnsupportedError
    value
    func
end

function Base.showerror(io::IO, err::FractionalCoefficient)
    print(io,
        "Fractional coefficient $(err.value) in $(err.func) is not supported.")
end

function getijval(f::MOI.ScalarAffineFunction{Float64}, n, m, index_map)
    q = ""
    for t in f.terms
        if !isinteger(t.coefficient)
            throw(FractionalCoefficient(t.coefficient, f))
        end
        q *= "$m 1 $(index_map[t.variable].value) $(n+1) $(t.coefficient/2)\n"
    end
    return q
end

function getijval(f::MOI.ScalarQuadraticFunction{Float64}, n, m, index_map)
    q = ""
    for qt in f.quadratic_terms
        if !isinteger(qt.coefficient)
            throw(FractionalCoefficient(qt.coefficient, f))
        end
        q *= "$m 1 $(index_map[qt.variable_1].value) $(index_map[qt.variable_2].value) $(qt.coefficient/2)\n"
    end
    for at in f.affine_terms
        if !isinteger(at.coefficient)
            throw(FractionalCoefficient(at.coefficient, f))
        end
        q *= "$m 1 $(index_map[at.variable].value) $(n+1) $(at.coefficient/2)\n"
    end
    return q
end


function model2bc(model::MOI.ModelLike)
    vars = MOI.get(model, MOI.ListOfVariableIndices())
    n = length(vars)
    Q = ""
    rhs = []
    me = mi = 0

    bin_cons = MOI.get(model, MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.ZeroOne}())
    var_attrs = MOI.get(model, MOI.ListOfVariableAttributesSet())
    if length(var_attrs) > 0
        throw(MOI.UnsupportedAttribute(var_attrs[1]))
    end
    i = 1
    index_map = MOI.IndexMap()
    for var in vars
        ci = MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(var.value)
        if !(ci in bin_cons)
            throw(VariableNotBinary(var))
        end
        index_map[var] = MOI.VariableIndex(i)
        i += 1
    end

    obj_sense = nothing
    model_attrs = MOI.get(model, MOI.ListOfModelAttributesSet())
    for attr in model_attrs
        if attr == MOI.ObjectiveSense()
            obj_sense = MOI.get(model, MOI.ObjectiveSense())
        elseif attr == MOI.Name() || attr isa MOI.ObjectiveFunction
            continue
        else
            throw(MOI.UnsupportedAttribute(attr))
        end
    end
    if obj_sense == MOI.FEASIBILITY_SENSE
        obj_fun_type = MOI.ScalarAffineFunction{Float64}
        obj_fun = MOI.ScalarAffineFunction(
            [
                MOI.ScalarAffineTerm(0.0, vars[1])
            ],
            0.0,
        )
    else
        obj_fun_type = MOI.get(model, MOI.ObjectiveFunctionType())
        obj_fun = MOI.get(model, MOI.ObjectiveFunction{obj_fun_type}())
    end
    Q *= getijval(obj_fun, n, 0, index_map)


    constraint_types = filter(
        ct -> ct[2] != MOI.ZeroOne,
        MOI.get(model, MOI.ListOfConstraintTypesPresent()),
    )
    for (F, S) in constraint_types
        cons_attrs = MOI.get(model, MOI.ListOfConstraintAttributesSet{F,S}())
        if length(cons_attrs) > 0
            throw(MOI.UnsupportedAttribute(cons_attrs[1]))
        end

        if !(F in [MOI.VariableIndex, MOI.ScalarAffineFunction{Float64}, MOI.ScalarQuadraticFunction{Float64}])
            throw(MOI.UnsupportedConstraint{F,S}())
        end

        cis = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        for ci in cis
            if S == MOI.EqualTo{Float64}
                me += 1
            elseif S == MOI.LessThan{Float64} || S == MOI.GreaterThan{Float64}
                mi += 1
            else
                throw(MOI.UnsupportedConstraint{F,S}())
            end
            fun = MOI.get(model, MOI.ConstraintFunction(), ci)
            set = MOI.get(model, MOI.ConstraintSet(), ci)
            set_const = MOI.constant(set)
            if !isinteger(set_const)
                throw(FractionalCoefficient(set_const, set))
            end
            push!(rhs, set_const)
            Q *= getijval(fun, n, mi + me, index_map)
            if S == MOI.LessThan{Float64}
                Q *= "$(mi + me) 2 $mi $mi 1.0\n"
            elseif S == MOI.GreaterThan{Float64}
                Q *= "$(mi + me) 2 $mi $mi -1.0\n"
            end
        end
    end

    output = ""
    if obj_sense == MOI.MIN_SENSE
        output *= "-1 = min problem\n"
    else
        output *= "1 = max problem\n"
    end
    output *= "$(mi + me) = number of constraints\n"
    output *= "$(mi == 0 ? 1 : 2) = number of blocks\n"
    output *= "$(n+1)$(mi > 0 ? ", -$mi" : "")\n"
    output *= "$(join(rhs, " "))\n"
    output *= Q

    return index_map, output
end


include("MOI_wrapper.jl")

end # module BiqCrunch
