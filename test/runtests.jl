import BiqCrunch
import MathOptInterface as MOI

using Test

function get_sample_model()
    src = MOI.Utilities.Model{Float64}()

    x = MOI.add_variables(src, 3)
    MOI.add_constraint(
        src,
        MOI.ScalarAffineFunction(
            [MOI.ScalarAffineTerm(1.0, x[1]), MOI.ScalarAffineTerm(1.0, x[2])],
            0.0,
        ),
        MOI.LessThan(1.0),
    )
    MOI.add_constraint(
        src,
        MOI.ScalarAffineFunction(
            [MOI.ScalarAffineTerm(1.0, x[2]), MOI.ScalarAffineTerm(1.0, x[3])],
            0.0,
        ),
        MOI.LessThan(1.0),
    )
    MOI.add_constraint(src, x[1], MOI.ZeroOne())
    MOI.add_constraint(src, x[2], MOI.ZeroOne())
    MOI.add_constraint(src, x[3], MOI.ZeroOne())

    obj_fun = MOI.ScalarAffineFunction(
        [
            MOI.ScalarAffineTerm(1.0, x[3]),
            MOI.ScalarAffineTerm(1.0, x[1]),
            MOI.ScalarAffineTerm(1.0, x[2]),
        ],
        0.0,
    )
    MOI.set(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), obj_fun)
    MOI.set(src, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    return src
end

# @testset "MOI" begin
#     include("MOI_wrapper.jl")
# end

@testset "e2e" begin
    src = get_sample_model()
    model = BiqCrunch.Optimizer()

    index, _ = MOI.optimize!(model, src)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(model, MOI.ObjectiveValue()) == 2.0

    obj_values = map(
        v -> MOI.get(model, MOI.VariablePrimal(), index[v]),
        MOI.get(src, MOI.ListOfVariableIndices()),
    )
    @test obj_values == [1, 0, 1]
    @test MOI.get(model, MOI.NodeCount()) == 1

end;
