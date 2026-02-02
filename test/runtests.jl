import BiqCrunch

# NOTE: Assumes BiqCrunch is installed in the home directory

bq_exe = expanduser("~/BiqCrunch/problems/generic/biqcrunch")
bq_params = expanduser("~/BiqCrunch/problems/generic/biq_crunch.param")
in = expanduser("~/BiqCrunch/problems/generic/example.lp")
println(BiqCrunch.solve(bq_exe, bq_params, in))

