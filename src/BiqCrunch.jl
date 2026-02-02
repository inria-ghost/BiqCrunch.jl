module BiqCrunch

# NOTE: Assumes BiqCrunch is installed in the home directory

function lp2bc(lp_file::String, bc_file::String)
	script_path = expanduser("~/BiqCrunch/tools/lp2bc.py")
	run(pipeline(`python3 $script_path $lp_file`, bc_file))
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

function solve(bq_exe::String, bq_params::String, lp_file::String)
	@assert isfile(bq_exe)
	@assert isfile(bq_params)
	@assert isfile(lp_file)

	bc_file = tempname()
	lp2bc(lp_file, bc_file)
	
	
	output = read(`$bq_exe $bc_file $bq_params`, String)
	re = r"Maximum value = (?<obj_value>\d+)\RSolution = \{(?<sol>[[:digit:][:blank:]]+)\}"
	m = match(re, output)

	map = get_var_mapping(bc_file)
	sol = Dict(collect(values(map)) .=> 0)
	broadcast(function(id) sol[map[id]] = 1 end, parse.(Int, split(m["sol"])))

	return parse(Int, m["obj_value"]), sol

end

end # module BiqCrunch
