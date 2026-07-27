using Test
using LyapunovExponents


@testset "LyapunovExponents.jl" begin

    @testset "System parameters" begin

        m = 2.0

        J_x, J_y, M, ϵ, p, q = get_SystemParameters(m)

        @test size(J_x) == (2,2)
        @test size(J_y) == (2,2)
        @test size(M) == (2,2)

        @test q > 0
        @test ϵ == 0.0

    end


    @testset "Hopping matrix construction" begin

        m = 2.0
        J_x, J_y, M, ϵ, p, q = get_SystemParameters(m)

        Ly = 4

        J, V, Xi, Wt = assign_J(J_x,Ly)

        @test size(J) == (2*Ly,2*Ly)
        @test size(V) == (2*Ly,Ly)
        @test size(Xi) == (Ly,Ly)
        @test size(Wt) == (Ly,2*Ly)

    end


    @testset "On-site matrix construction" begin

        m = 2.0
        J_x, J_y, M, ϵ, p, q = get_SystemParameters(m)

        Ly = 4

        Mclean = assign_M(M,J_y,Ly,p)

        @test size(Mclean) == (2*Ly,2*Ly)

    end


    @testset "Lyapunov calculation small system" begin

        m = 2.0
        W = 0.1

        Ly = 4
        Nx = 20

        J_x,J_y,M,ϵ,p,q = get_SystemParameters(m)

        Mclean = assign_M(M,J_y,Ly,p)

        J,V,Xi,Wt = assign_J(J_x,Ly)

        λ_list,Q_prev,R = get_LyapunovList(
            Mclean,
            V,
            Xi,
            Wt,
            ϵ,
            Ly,
            Nx,
            W,
            q
        )

        @test length(λ_list) == 2*Ly
        @test size(Q_prev) == (2*Ly,2*Ly)
        @test size(R) == (2*Ly,2*Ly)

        @test all(isfinite, real(λ_list))

    end

end