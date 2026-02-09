module BiqCrunch

import MathOptInterface as MOI

# NOTE: Assumes BiqCrunch is installed in the home directory
#
#
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

function lp2bc(lp_file::String, bc_file::String)
	lp_model = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_LP)
	MOI.read_from_file(lp_model, lp_file)
	output = ""

	# Output variable names
	vars = MOI.get(lp_model, MOI.ListOfVariableIndices())
	for var in vars
		ci = MOI.ConstraintIndex{MOI.VariableIndex, MOI.ZeroOne}(var.value)
		@assert MOI.is_valid(lp_model, ci)
	end
	n = length(vars)
	var_strings = map(v -> 
		   "#\t$(v.value): $(MOI.get(lp_model, MOI.VariableName(), v))",
		   vars)
	output *= "# List of binary variables:\n$(join(var_strings, "\n"))\n"

	# Output max/min
	obj_sense = MOI.get(lp_model, MOI.ObjectiveSense())
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
	obj_fun_type = MOI.get(lp_model, MOI.ObjectiveFunctionType())
	obj_fun = MOI.get(lp_model, MOI.ObjectiveFunction{obj_fun_type}())
	Q *= getijval(obj_fun_type, obj_fun, n, 0)
	mi = me = 0
	constraint_types = filter(x -> x[1] != MOI.VariableIndex, MOI.get(lp_model, MOI.ListOfConstraintTypesPresent()))
	for (F, S) in constraint_types 
		cis = MOI.get(lp_model, MOI.ListOfConstraintIndices{F, S}())
		for ci in cis
			if S == MOI.EqualTo{Float64} me += 1 else mi += 1 end
			fun = MOI.get(lp_model, MOI.ConstraintFunction(), ci)
			set = MOI.get(lp_model, MOI.ConstraintSet(), ci)
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

	write(bc_file, output)
end

function get_var_mapping(bc_file::String)
	map = Dict{Int,String}()
	re = r"#[[:blank:]]+(?<id>\d+):[[:blank:]]+(?<varname>[[:alnum:]]+)"
	f = read(bc_file, String)
	while occursin(re, f)
		m = match(re, f)
		map[parse(Int, m["id"])] = m["varname"]
		next = m.offset + length(m.match)
		f = f[next:end]
	end
	return map
end

function solve(bq_exe::String, bq_params::String, lp_file::String, lp2bcfun=lp2bc)
	@assert isfile(bq_exe)
	@assert isfile(bq_params)
	@assert isfile(lp_file)

	bc_file = tempname()
	lp2bcfun(lp_file, bc_file)
	
	
	output = read(`$bq_exe $bc_file $bq_params`, String)
	re = r"Maximum value = (?<obj_value>\d+)\RSolution = \{(?<sol>[[:digit:][:blank:]]+)\}"
	m = match(re, output)

	map = get_var_mapping(bc_file)
	sol = Dict(collect(values(map)) .=> 0)
	broadcast(function(id) sol[map[id]] = 1 end, parse.(Int, split(m["sol"])))

	return parse(Int, m["obj_value"]), sol

end

end # module BiqCrunch
