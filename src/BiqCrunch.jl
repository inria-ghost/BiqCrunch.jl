module BiqCrunch

import MathOptInterface as MOI

function getijval(F, f, n, m, index_map)
    q = ""
    if F == MOI.ScalarAffineFunction{Float64}
        for t in f.terms
            q *= "$m 1 $(index_map[t.variable].value) $(n+1) $(t.coefficient/2)\n"
        end
    elseif F == MOI.ScalarQuadraticFunction{Float64}
        for qt in f.quadratic_terms
            q *= "$m 1 $(index_map[qt.variable_1].value) $(index_map[qt.variable_2].value) $(qt.coefficient/2)\n"
        end
        for at in f.affine_terms
            q *= "$m 1 $(index_map[at.variable].value) $(n+1) $(at.coefficient/2)\n"
        end
    else
        error("unsupported function type: $F")
    end
    return q
end

function model2bc(model::MOI.ModelLike, bcfile::String)
    obj_func = nothing
    obj_sense = nothing
    model_attrs = MOI.get(model, MOI.ListOfModelAttributesSet())
    for attr in model_attrs
        if attr == MOI.ObjectiveSense()
            obj_sense = MOI.get(model, MOI.ObjectiveSense())
        elseif attr == MOI.Name()
            continue
        elseif attr isa MOI.ObjectiveFunction
            obj_func = attr
        else
            throw(MOI.UnsupportedAttribute(attr))
        end
    end

    var_attrs = MOI.get(model, MOI.ListOfVariableAttributesSet())
    for attr in var_attrs
        if attr != MOI.VariableName()
            throw(MOI.UnsupportedAttribute(attr))
        end
    end
    index_map = MOI.IndexMap()
    vars = MOI.get(model, MOI.ListOfVariableIndices())
    i = 1
    for var in vars
        index_map[var] = MOI.VariableIndex(i)
        i += 1
        # ci = MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(var.value)
        # @assert MOI.is_valid(model, ci)
    end
    n = length(vars)

    rhs = [];
    Q = "";
    if obj_sense == MOI.MIN_SENSE || obj_sense == MOI.MAX_SENSE
        obj_fun_type = MOI.get(model, MOI.ObjectiveFunctionType())
        obj_fun = MOI.get(model, MOI.ObjectiveFunction{obj_fun_type}())
        Q *= getijval(obj_fun_type, obj_fun, n, 0, index_map)
    else
        obj_fun = MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm(0, MOI.VariableIndex(1))],
            0,
        )
        Q *= getijval(MOI.ScalarAffineFunction{Float64}, obj_fun, n, 0, index_map)
    end
    mi = me = 0
    constraint_types = filter(
        x -> x[1] != MOI.VariableIndex,
        MOI.get(model, MOI.ListOfConstraintTypesPresent()),
    )
    for (F, S) in constraint_types
        cons_attrs = MOI.get(model, MOI.ListOfConstraintAttributesSet{F,S}())
        for attr in cons_attrs
            if attr != MOI.ConstraintName()
                throw(MOI.UnsupportedAttribute(attr))
            end
        end
        cis = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        for ci in cis
            if S == MOI.EqualTo{Float64}
                me += 1
            else
                mi += 1
            end
            fun = MOI.get(model, MOI.ConstraintFunction(), ci)
            set = MOI.get(model, MOI.ConstraintSet(), ci)
            push!(rhs, MOI.constant(set))
            Q *= getijval(F, fun, n, mi + me, index_map)
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

    write(bcfile, output)
    return index_map
end


include("MOI_wrapper.jl")

end # module BiqCrunch
