import BiqCrunch

# NOTE: Assumes BiqCrunch is installed in the home directory
#

function lp2bcpy(lp_file::String, bc_file::String)
	script_path = expanduser("~/BiqCrunch/tools/lp2bc.py")
	run(pipeline(`python3 $script_path $lp_file`, bc_file))
end

bq_exe = expanduser("~/BiqCrunch/problems/generic/biqcrunch")
bq_params = expanduser("~/BiqCrunch/problems/generic/biq_crunch.param")
problems = [
	expanduser("~/BiqCrunch/problems/generic/example.lp"),
	expanduser("~/BiqCrunch/problems/generic/examples/randprob.lp"),
	expanduser("~/BiqCrunch/problems/k-cluster/example.lp"),
	# expanduser("~/BiqCrunch/problems/generic/examples/randprob_square.lp"),
	# expanduser("~/BiqCrunch/problems/generic/examples/randprob_prod.lp"),
	]

for p in problems
	r1 = BiqCrunch.solve(bq_exe, bq_params, p)
	r2 = BiqCrunch.solve(bq_exe, bq_params, p, lp2bcpy)
	@assert r1 == r2
	println("$p : OK")
end

