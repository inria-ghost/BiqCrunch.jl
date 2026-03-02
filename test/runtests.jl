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
problems = [
    expanduser("~/BiqCrunch/problems/generic/example.lp"),
    expanduser("~/BiqCrunch/problems/generic/examples/randprob.lp"),
]

for p in problems
    println(p)
    model = BiqCrunch.Optimizer(bq_exe)
    src = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_LP)
    MOI.read_from_file(src, p)
    index, _ = MOI.optimize!(model, src)
    println(MOI.get(model, MOI.TerminationStatus()))
    println(MOI.get(model, MOI.PrimalStatus()))
    println(MOI.get(model, MOI.ObjectiveValue()))
    for var in MOI.get(src, MOI.ListOfVariableIndices())
        println("$var  =>  $(MOI.get(model, MOI.VariablePrimal(), index[var]))")
    end
    println(MOI.get(model, MOI.SolveTimeSec()))
    println(MOI.get(model, MOI.NodeCount()))
end
