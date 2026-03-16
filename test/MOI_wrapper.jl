# ============================ /test/MOI_wrapper.jl ============================
module TestBiqCrunch

import BiqCrunch
using Test

import MathOptInterface as MOI

const OPTIMIZER = MOI.instantiate(MOI.OptimizerWithAttributes(BiqCrunch.Optimizer))

const BRIDGED = MOI.instantiate(
    BiqCrunch.Optimizer,
    with_cache_type = Float64,
    with_bridge_type = Float64,
)

# See the docstring of MOI.Test.Config for other arguments.
const CONFIG = MOI.Test.Config(
    # Modify tolerances as necessary.
    atol = 1e-6,
    rtol = 1e-6,
    # Use MOI.LOCALLY_SOLVED for local solvers.
    optimal_status = MOI.OPTIMAL,
    # Pass attributes or MOI functions to `exclude` to skip tests that
    # rely on this functionality.
    exclude = Any[MOI.ConstraintDual,],
)

"""
    runtests()

This function runs all functions in the this Module starting with `test_`.
"""
function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

"""
    test_runtests()

This function runs all the tests in MathOptInterface.Test.

Pass arguments to `exclude` to skip tests for functionality that is not
implemented or that your solver doesn't support.
"""
function test_runtests()
    MOI.Test.runtests(
        BRIDGED,
        CONFIG,
        exclude = [
            "test_linear_FEASIBILITY_SENSE", # Requires incremental interface
            "test_quadratic_nonconvex_constraint_basic", # Requires incremental interface
            # NOTE: these tests should require incremental interface but do not. 
            "test_attribute_RawStatusString",
            "test_attribute_SolveTimeSec",
            "test_basic_ScalarAffineFunction_Integer",
            "test_basic_ScalarAffineFunction_Semiinteger",
            "test_basic_ScalarQuadraticFunction_Integer",
            "test_basic_ScalarQuadraticFunction_Semiinteger",
            "test_basic_VariableIndex_Integer",
            "test_basic_VariableIndex_Semiinteger",
            "test_basic_VectorAffineFunction_Circuit",
            "test_basic_VectorOfVariables_Circuit",
            "test_basic_VectorQuadraticFunction_Circuit",
            "test_model_copy_to_UnsupportedAttribute",
        ],
        # This argument is useful to prevent tests from failing on future
        # releases of MOI that add new tests. Don't let this number get too far
        # behind the current MOI release though. You should periodically check
        # for new tests to fix bugs and implement new features.
        exclude_tests_after = v"0.10.5",
    )
    return
end

"""
    test_SolverName()

You can also write new tests for solver-specific functionality. Write each new
test as a function with a name beginning with `test_`.
"""
function test_SolverName()
    @test MOI.get(BiqCrunch.Optimizer(), MOI.SolverName()) == "BiqCrunch"
    return
end

function test_TimeLimitSec()
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
end


function test_NodeLimit()
    paramfile = tempname()
    write(paramfile, "")
    model = BiqCrunch.Optimizer("", paramfile)
    @test MOI.get(model, MOI.NodeLimit()) == nothing

    MOI.set(model, MOI.NodeLimit(), 5)
    @test MOI.get(model, MOI.NodeLimit()) == 5

    new_params = read(model.paramfile, String)
    expected_params = "node_limit = 5"
    @test new_params == expected_params

    params = """
    # this is a comment
    seed = 1234
    time_limit = 1.5
    node_limit = 2
    maxNiter = 100
    """
    write(paramfile, params)
    model = BiqCrunch.Optimizer("", paramfile)
    @test MOI.get(model, MOI.NodeLimit()) == 2
    MOI.set(model, MOI.NodeLimit(), 3)
    new_params = read(model.paramfile, String)
    expected_params = """
    # this is a comment
    seed = 1234
    time_limit = 1.5
    node_limit = 3
    maxNiter = 100
    """
    @test new_params == expected_params

    params = """
    # this is a comment
    seed = 1234
    # node_limit = 1
    maxNiter = 100
    """
    write(paramfile, params)
    model = BiqCrunch.Optimizer("", paramfile)
    @test MOI.get(model, MOI.NodeLimit()) == nothing
    MOI.set(model, MOI.NodeLimit(), 2)
    new_params = read(model.paramfile, String)
    expected_params = """
    # this is a comment
    seed = 1234
    # node_limit = 1
    maxNiter = 100
    node_limit = 2"""
    @test new_params == expected_params
    MOI.set(model, MOI.NodeLimit(), nothing)
    new_params = read(model.paramfile, String)
    expected_params = """
    # this is a comment
    seed = 1234
    # node_limit = 1
    maxNiter = 100
    """
    @test new_params == expected_params
    @test MOI.get(model, MOI.NodeLimit()) == nothing
end

function test_parse_solver_output()
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


end



end # module TestBiqCrunch

# This line at tne end of the file runs all the tests!
TestBiqCrunch.runtests()
