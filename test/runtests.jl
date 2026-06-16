import BiqCrunch
import MathOptInterface as MOI

using Test

function empty_model()
    return MOI.Utilities.Model{Float64}()
end

function feas_sense_model()
    src = MOI.Utilities.Model{Float64}()

    x = MOI.add_variables(src, 3)
    MOI.add_constraint(src, x[1], MOI.ZeroOne())
    MOI.add_constraint(src, x[2], MOI.ZeroOne())
    MOI.add_constraint(src, x[3], MOI.ZeroOne())
    MOI.add_constraint(
        src,
        MOI.ScalarAffineFunction(
            [MOI.ScalarAffineTerm(1.0, x[1]), MOI.ScalarAffineTerm(1.0, x[2])],
            0.0,
        ),
        MOI.LessThan(1.0)
    )

    MOI.set(src, MOI.ObjectiveSense(), MOI.FEASIBILITY_SENSE)
    return src

end

function no_cons_model()
    src = MOI.Utilities.Model{Float64}()

    x = MOI.add_variables(src, 3)
    MOI.add_constraint(src, x[1], MOI.ZeroOne())
    MOI.add_constraint(src, x[2], MOI.ZeroOne())
    MOI.add_constraint(src, x[3], MOI.ZeroOne())

    obj_fun = MOI.ScalarAffineFunction(
        [
            MOI.ScalarAffineTerm(1.0, x[3]),
            MOI.ScalarAffineTerm(1.0, x[1]),
            MOI.ScalarAffineTerm(1.0, x[2]),
        ],
        2.0,
    )
    MOI.set(src, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.set(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), obj_fun)
    return src

end

function const_obj_model()
    src = MOI.Utilities.Model{Float64}()

    x = MOI.add_variables(src, 3)
    MOI.add_constraint(
        src,
        MOI.ScalarAffineFunction(
            [MOI.ScalarAffineTerm(1.0, x[1]), MOI.ScalarAffineTerm(1.0, x[2])],
            0.0,
        ),
        MOI.LessThan(1.0)
    )
    MOI.add_constraint(src, x[1], MOI.ZeroOne())
    MOI.add_constraint(src, x[2], MOI.ZeroOne())
    MOI.add_constraint(src, x[3], MOI.ZeroOne())

    obj_fun = MOI.ScalarAffineFunction{Float64}([], 5.0)
    MOI.set(src, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.set(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), obj_fun)
    return src
end

function non_binary_model()
    src = MOI.Utilities.Model{Float64}()

    x = MOI.add_variables(src, 3)
    MOI.add_constraint(
        src,
        MOI.ScalarAffineFunction(
            [MOI.ScalarAffineTerm(1.0, x[1]), MOI.ScalarAffineTerm(1.0, x[2])],
            0.0,
        ),
        MOI.LessThan(1.0)
    )
    MOI.add_constraint(src, x[1], MOI.ZeroOne())
    MOI.add_constraint(src, x[3], MOI.ZeroOne())

    obj_fun = MOI.ScalarAffineFunction{Float64}([], 5.0)
    MOI.set(src, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.set(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), obj_fun)
    return src

end

function sample_model()
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

function fractional_model()
    src = MOI.Utilities.Model{Float64}()

    x = MOI.add_variables(src, 3)
    MOI.add_constraint(
        src,
        MOI.ScalarAffineFunction(
            [MOI.ScalarAffineTerm(1.5, x[1]), MOI.ScalarAffineTerm(1.0, x[2])],
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

@testset "MOI" begin
    include("MOI_wrapper.jl")
end


@testset "e2e" begin
    src = sample_model()
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

    src = fractional_model()
    model = BiqCrunch.Optimizer()
    @test_throws BiqCrunch.FractionalCoefficient MOI.optimize!(model, src)

    src = non_binary_model()
    model = BiqCrunch.Optimizer()
    @test_throws BiqCrunch.VariableNotBinary MOI.optimize!(model, src)

    src = empty_model()
    model = BiqCrunch.Optimizer()
    MOI.optimize!(model, src)
    @test MOI.get(model, MOI.SolveTimeSec()) == 0.0
    @test MOI.get(model, MOI.ObjectiveValue()) == 0.0
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL

    src = feas_sense_model()
    model = BiqCrunch.Optimizer()
    MOI.optimize!(model, src)
    @test MOI.get(model, MOI.ObjectiveValue()) == 0.0

    src = no_cons_model()
    model = BiqCrunch.Optimizer()
    MOI.optimize!(model, src)
    @test MOI.get(model, MOI.ObjectiveValue()) == 5.0

    src = const_obj_model()
    model = BiqCrunch.Optimizer()
    MOI.optimize!(model, src)
    @test MOI.get(model, MOI.ObjectiveValue()) == 5.0

end;
