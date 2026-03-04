import BiqCrunch
import MathOptInterface as MOI

using Test


# NOTE: BiqCrunch.jl
@testset "model2bc" begin

    function lp2bcpy(lp_file::String, bc_file::String)
        script_path = expanduser("~/BiqCrunch/tools/lp2bc.py")
        run(pipeline(`python3 $script_path $lp_file`, bc_file))
    end
    #
    # TODO: add tests for bcfile generation

end;

# NOTE: MOI_wrapper.jl
@testset "emptying model" begin

    # TODO:

end;

@testset "timelimitsec" begin
    paramfile = tempname()
    write(paramfile, "")
    model = BiqCrunch.Optimizer("", paramfile)
    @test MOI.get(model, MOI.TimeLimitSec()) == nothing

    MOI.set(model, MOI.TimeLimitSec(), 2.5)
    @test MOI.get(model, MOI.TimeLimitSec()) == 2.5

    new_params = read(model.paramfile, String)
    expected_params = "time_limit = 2.5"
    @test new_params == expected_params

    params = """
    # this is a comment
    seed = 1234
    time_limit = 1.5
    maxNiter = 100
    """
    write(paramfile, params)
    model = BiqCrunch.Optimizer("", paramfile)
    @test MOI.get(model, MOI.TimeLimitSec()) == 1.5
    MOI.set(model, MOI.TimeLimitSec(), 2.5)
    new_params = read(model.paramfile, String)
    expected_params = """
    # this is a comment
    seed = 1234
    time_limit = 2.5
    maxNiter = 100
    """
    @test new_params == expected_params

    params = """
    # this is a comment
    seed = 1234
    # time_limit = 1.5
    maxNiter = 100
    """
    write(paramfile, params)
    model = BiqCrunch.Optimizer("", paramfile)
    @test MOI.get(model, MOI.TimeLimitSec()) == nothing
    MOI.set(model, MOI.TimeLimitSec(), 2.5)
    new_params = read(model.paramfile, String)
    expected_params = """
    # this is a comment
    seed = 1234
    # time_limit = 1.5
    maxNiter = 100
    time_limit = 2.5"""
    @test new_params == expected_params
    MOI.set(model, MOI.TimeLimitSec(), nothing)
    new_params = read(model.paramfile, String)
    expected_params = """
    # this is a comment
    seed = 1234
    # time_limit = 1.5
    maxNiter = 100
    """
    @test new_params == expected_params
    @test MOI.get(model, MOI.TimeLimitSec()) == nothing

end;

@testset "_parse_solver_output" begin
    # Case 1: Infeasible solution
    output = """
    Output file: ./infeasible.bc.output
    Input file:  ./infeasible.bc
    Parameter file: ./biq_crunch.param
    Nodes = 1
    Root node bound = -1000000000.00000
    Problem is infeasible.
    CPU time = 0.0009 s"""
    expected = BiqCrunch._Solution(
        "./infeasible.bc",
        "./infeasible.bc.output",
        "./biq_crunch.param",
        1,
        -1000000000.0,
        true,
        0,
        0,
        [],
        Dict{Int64,Int64}(),
        0.0009,
    )
    @test BiqCrunch._parse_solver_output(output) == expected

    # Case 2: Optimal solution
    output = """
    Output file: ./problems/generic/example.bc.output_1
    Input file:  ./problems/generic/example.bc
    Parameter file: ./biq_crunch.param
    Node 0 Feasible solution 31
    Node 1 Feasible solution 43
    Nodes = 3
    Root node bound = 47.42796
    Maximum value = 43
    Solution = { 1 2 3 }
    CPU time = 0.0016 s"""
    expected = BiqCrunch._Solution(
        "./problems/generic/example.bc",
        "./problems/generic/example.bc.output_1",
        "./biq_crunch.param",
        3,
        47.42796,
        false,
        43,
        0,
        [1, 2, 3],
        Dict{Int64,Int64}(),
        0.0016,
    )
    @test BiqCrunch._parse_solver_output(output) == expected

    # Case 3: Early stop
    output = """
    Output file: problems/max-indep-set/examples/san200_0.9_3.bc.output_6
    Input file:  problems/max-indep-set/examples/san200_0.9_3.bc
    Parameter file: ./biq_crunch.param
    Node 0 Feasible solution 31
    Node 1 Feasible solution 34
    Nodes = 1
    Root node bound = 45.59183
    Best value = 34
    Current bound = 45.59183
    Gap = 34.09%
    CPU time = 2.1353 s"""
    expected = BiqCrunch._Solution(
        "problems/max-indep-set/examples/san200_0.9_3.bc",
        "problems/max-indep-set/examples/san200_0.9_3.bc.output_6",
        "./biq_crunch.param",
        1,
        45.59183,
        false,
        34,
        34.09,
        [],
        Dict{Int64,Int64}(),
        2.1353,
    )
    @test BiqCrunch._parse_solver_output(output) == expected

end;

@testset "e2e" begin

    # NOTE: Assumes BiqCrunch is installed in the home directory
    bq_exe = expanduser("~/BiqCrunch/problems/generic/biqcrunch")
    problems = [
        expanduser("~/BiqCrunch/problems/generic/example.lp"),
        expanduser("~/BiqCrunch/problems/generic/examples/randprob.lp"),
    ]

    for p in problems
        println(p)
        model = BiqCrunch.Optimizer(bq_exe)
        println(summary(model))
        MOI.set(model, MOI.TimeLimitSec(), 1)
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
end
