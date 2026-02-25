import BiqCrunch
import MathOptInterface as MOI

# NOTE: Assumes BiqCrunch is installed in the home directory

## TODO:
# * add tests for bcfile generation

function lp2bcpy(lp_file::String, bc_file::String)
    script_path = expanduser("~/BiqCrunch/tools/lp2bc.py")
    run(pipeline(`python3 $script_path $lp_file`, bc_file))
end

bq_exe = expanduser("~/BiqCrunch/problems/generic/biqcrunch")
bq_params = expanduser("~/BiqCrunch/problems/generic/biq_crunch.param")
problems = [
    expanduser("~/BiqCrunch/problems/generic/example.lp"),
    expanduser("~/BiqCrunch/problems/generic/examples/randprob.lp"),
]

for p in problems
    model = BiqCrunch.Optimizer(bq_exe, bq_params)
    src = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_LP)
    MOI.read_from_file(src, p)
    MOI.optimize!(model, src)
    println(MOI.get(model, MOI.ObjectiveValue()))
    for var in MOI.get(src, MOI.ListOfVariableIndices())
        println("$var  =>  $(MOI.get(model, MOI.VariablePrimal(), var))")
    end
end
