module BiqCrunch

import MathOptInterface as MOI

function getijval(F, f, n, m)
    q = ""
    if F == MOI.ScalarAffineFunction{Float64}
        for t in f.terms
            q *= "$m 1 $(t.variable.value) $(n+1) $(t.coefficient/2)\n"
        end
    elseif F == MOI.ScalarQuadraticFunction{Float64}
        for qt in f.quadratic_terms
            q *= "$m 1 $(qt.variable_1.value) $(qt.variable_2.value) $(qt.coefficient/2)\n"
        end
        for at in f.affine_terms
            q *= "$m 1 $(at.variable.value) $(n+1) $(at.coefficient/2)\n"
        end
    else
        error("unsupported function type: $F")
    end
    return q
end

function model2bc(model::MOI.ModelLike, bcfile::String)
    output = ""

    # Output variable names
    vars = MOI.get(model, MOI.ListOfVariableIndices())
    for var in vars
        ci = MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(var.value)
        @assert MOI.is_valid(model, ci)
    end
    n = length(vars)
    var_strings = map(v -> "#\t$(v.value): $(MOI.get(model, MOI.VariableName(), v))", vars)
    output *= "# List of binary variables:\n$(join(var_strings, "\n"))\n"

    # Output max/min
    obj_sense = MOI.get(model, MOI.ObjectiveSense())
    if obj_sense == MOI.MIN_SENSE
        output *= "-1 = min problem\n"
    elseif obj_sense == MOI.MAX_SENSE
        output *= "1 = max problem\n"
    else
        error("feasibility sense not allowed")
    end

    # Handle constraints
    rhs = [];
    Q = "";
    obj_fun_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj_fun = MOI.get(model, MOI.ObjectiveFunction{obj_fun_type}())
    Q *= getijval(obj_fun_type, obj_fun, n, 0)
    mi = me = 0
    constraint_types = filter(
        x -> x[1] != MOI.VariableIndex,
        MOI.get(model, MOI.ListOfConstraintTypesPresent()),
    )
    for (F, S) in constraint_types
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
            Q *= getijval(F, fun, n, mi + me)
            if S == MOI.LessThan{Float64}
                Q *= "$(mi + me) 2 $mi $mi 1.0\n"
            elseif S == MOI.GreaterThan{Float64}
                Q *= "$(mi + me) 2 $mi $mi -1.0\n"
            end
        end
    end

    output *= "$(mi + me) = number of constraints\n"
    output *= "$(mi == 0 ? 1 : 2) = number of blocks\n"
    output *= "$(n+1)$(mi > 0 ? ", -$mi" : "")\n"
    output *= "$(join(rhs, " "))\n"
    output *= Q

    write(bcfile, output)
end


include("MOI_wrapper.jl")

end # module BiqCrunch
