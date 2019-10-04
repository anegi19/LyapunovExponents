#-------------------------------------- FUNCTIONS to calculate Lyapunovs------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------
#=
Function to construct and return the Hopping matrix 𝐉 and its Singular Value Decomposition,
given that there are Ly sites in the supercell and
𝐉 = BLOCK_Matrix( J_x, repeated N times )
--------------------------------------------------
If SVD of J_x = v.Ξ.w'

(where Ξ = diagonal matrix with Singular Values of J_x along its diagonal in descending order)

SVD of 𝐉 = V.Xi.Wt

such that:

V= BLOCK_Matrix(v, repeated N times)
Xi= BLOCK_Matrix(Ξ, repeated N times)
Wt= BLOCK_Matrix(w', repeated N times)
---------------------------------------------------

=#





@everywhere function assign_J(J_x::Array{Complex{Float64},2},Ly::Int64)

    𝐈= convert(Array{Complex{Float64},2}, Matrix(Diagonal(ones(Ly))))

    F= svd(J_x)
    v=F.U[:,1]
    w=F.V[:,1]

    Xi=𝐈
          𝐕=kron(𝐈,v)
          𝐖t=kron(𝐈,w')
          𝐉=kron(𝐈,J_x)

    return(𝐉,𝐕,Xi,𝐖t)

end


#-----------------------------------------------------------------------------------------------------------------------


#=
Function to construct and return the 'clean' on-site matrix 𝐌,
given that there are Ly sites in the supercell and

𝐉 = BLOCK_Matrix( M, J_y', J_y : repeated Ly times along 0,-1 and 1 diagonal respectively)

=#


@everywhere function assign_M(M::Array{Float64,2},J_y::Array{Complex{Float64},2},Ly::Int64,p::Int64)

                    𝐌=Array{Complex{Float64},2}
                     𝐈=Diagonal(ones(Ly))

                     𝐈_up= diagm(1 => ones(Ly-1))
                     𝐈_down= diagm(-1 => ones(Ly-1))

                    𝐌= kron(𝐈,M)+ kron(𝐈_up,J_y')+kron(𝐈_down,J_y)

       if(p==1) #pbc=ON
                              𝐈_PBCup = diagm((Ly-1) => ones(1))
                              𝐈_PBCdown = diagm(-(Ly-1) => ones(1))
                             𝐌+=kron(𝐈_PBCup,J_y)+kron(𝐈_PBCdown,J_y')
       end
       return(𝐌)
end


#=

Function to calculate and store (1) λ_list (Lyapunov spectrum) (2)Last value of Qprev at a given value of (m,W) of a 2D disordered system
with (x,y) dimensions = (Nx,Ly)

-----------------------------------------------------------------------------------------------------------------------
Inputs:
                           M :: Array{Float64},2},Array{Complex{Float64},2} ::On site (clean) matrix of a supercell
           V,Xi,Wt :: Array{Float64},2},Array{Complex{Float64},2}::SVD OF 𝐉
         Ly :: Int64                                       ::Number of sites in a supercell (transverse length of the system)
         Nx :: Int64                                       ::Number of supercells (longitudinal length of the system)
         Wd :: Float64                                     ::Disorder Strength
   dir_name :: String                                      ::Directory to store the Lyapunov spectrum file, usually the current working directory (each file is refered to by its jobID )
          q :: Int64                                       ::Number of QR decomposition steps to skip
       jobID:: Int64                                       ::ID corresponding to each job. Here 1 job corresponds to 1 (m,W,Ly) set
------------------------------------------------------------------------------------------------------------------------
Outputs: doesn't return anything

  λ_list :: Array{Float64,1}                            ::[ λ_1, λ_2,...λ_2r]  in descending order
  last value of R :: Array{Float64,1}                            ::[ λ_1, λ_2,...λ_2r]  in descending order
-------------------------------------------------------------------------------------------------------------------------


=#




@everywhere function get_LyapunovList(M::Array{Complex{Float64},2},V::Array{Complex{Float64},2},Xi::Array{Complex{Float64},2},Wt::Array{Complex{Float64},2},E::Float64,Ly::Int64,Nx::Int64,Wd::Float64,q::Int64)



 #   LOCAL FUNCTIONS
 #  ==========================================

    # Standard typecasting for matrices: Everything should be a complex matrix
    function stdform(mat)
        convert(Array{Complex{Float64},2},Matrix(mat))
    end


    # Memory-efficient matrix inverse computation
    function myinv!(A::Array{Complex{Float64},2}, Y::Array{Complex{Float64},2})
        Ylen=size(A,1);
        Y .= 0 .* A;
        @inbounds @simd for i in 1:Ylen
         Y[i,i] = 1.0;
        end
        #print(typeof(A),typeof(Y),"Div"); @time
        ldiv!(lu!(A),Y)
    end


    # In-place multiplier for 3 nonsquare matrices, as needed to compute Gab
    function comp_overlap!(out, list)
      mul!(temp_rN, list[1], list[2])
      mul!(out, temp_rN, list[3])
    end


    # In-place submatrix assignments
    function assign_submat!(A::Array{Complex{Float64},2},B::Array{Complex{Float64},2},m::Int64,n::Int64)
     Blen = size(B,1)
     @inbounds @simd for j in n:(n+Blen-1)
         @inbounds for i in m:(m+Blen-1)
             A[i,j] = B[i-m+1, j-n+1];
         end
     end
    end


#   VARIABLE INITIALIZATIONS
#  ==========================================
    #q =size of the blocks of QR
    #r= rank of the 𝐉  Matrix
    #size of 𝐓  matrix = 2r X 2r
     r = size(Xi,1)
     sizeT = 2*r
     N = size(M,1)

     unit = 1.0+0.0*im;

     # ===== r x r matrices =======
     O = stdform(Diagonal(zeros(r)))  # Zero matrix of size: r x r
     Id = stdform(Diagonal(ones(r)))  #Identity matrix of size: r X r
     negId = (-1).*Id;
     Mtemp = copy(Id);
     Gvv, Gvw, Gwv, Gww = copy(Id),copy(Id),copy(Id),copy(Id)

     # ===== 2r x 2r matrices =======
     T_x = stdform(Diagonal(ones(sizeT)))
     A, B, Ttemp, temp2 =copy(T_x), copy(T_x), copy(T_x), copy(T_x)
     It = stdform(Diagonal(ones(sizeT)))  #Identity matrix of size: r X r
     Q_prev, R = copy(T_x), copy(T_x)
     # tempmatT, tempmat2 = copy(T_x), copy(T_x)



     # ===== N x N matrices =======
      Im = stdform(Diagonal(ones(N))) #Identity matrix of size: N x N
      G, Mtemp = copy(Im), copy(Im)

      disordered_M = copy(M)

      # Need this as intermediate matrix for the computation of G_ab in comp_overlap!()
      temp_rN = stdform(zeros(r,N))

      #V'=Vt ;V and Vt are Hermitian conjugates.
      #Wt'=W ;W and Wt are Hermitian conjugates.
      Vd = V';
      Wtd = Wt';



        # # Low level (LAPACK) coding
        # # ===========================================================================
        #
        #   import ..LinearAlgebra: BlasInt
        #
        #   tempvec = copy(λ_list)
        #   tau = vec(copy(λ_list))
        #   heapsz = 100+4*sizeT*sizeT;   # Must be at least sizeT(2sizeT + 1)
        #   heap = vec(stdform(zeros(heapsz,1)))
        #
        #   #  LAPACK function to compute the QR decomposition with preallocated memory
        #
        #   # function myqr!(A::AbstractMatrix{Complex{Float64}}, Q::AbstractMatrix{Complex{Float64}}, tau::AbstractVector{Complex{Float64}})
        #   function myqr!(A, Q, tau, heap)
        #       LAPACKqr!(A, tau, heap)
        #       # This returns Q in a compressed form as a set of Householder reflections.
        #       # Next we need to recover Q.
        #
        #       # First allocate parts of the heap for various temporary variables
        #       ltemp1 = reshape(view(heap,1:sizeT*sizeT), (sizeT, sizeT))
        #       ltemp2 = temp2
        #       v = tempvec
        #       v .= 0 .* v
        #       # temp2 = reshape(view(heap,sizeT*sizeT+1:2*sizeT*sizeT), (sizeT, sizeT))
        #
        #       Q .= It;  # initialize as Identity
        #
        #       # Q .= 0 .* Q
        #       # @inbounds @simd for i in 1:sizeT
        #       #     Q[i,i] = unit
        #       # end
        #
        #       # print("Recover Q:"); @time
        #       @inbounds @simd for i in 1:sizeT
        #           fill!(view(v,1:i), 0)
        #           v[i] = unit
        #           v[i+1:sizeT] .= A[i+1:sizeT,i];
        #           # fill!(view(A, i+1:sizeT, i), 0)
        #           ltemp1 .= v .* v';
        #           ltemp2 .= It .- tau[i] .*ltemp1
        #           mul!(ltemp1, Q, ltemp2)
        #           Q .= ltemp1
        #       end
        #       Q,A
        #   end
        #
        #
        #   function LAPACKqr!(A::AbstractMatrix{Complex{Float64}}, tau::AbstractVector{Complex{Float64}}, work::AbstractVector{Complex{Float64}})
        #       m, n  = size(A)
        #       lwork = BlasInt(-1)
        #       info  = Ref{BlasInt}()
        #         for i = 1:2      # first call returns lwork as work[1]
        #           ccall((:zgeqrf_64_, Base.liblapack_name), Cvoid,
        #             (Ref{BlasInt}, Ref{BlasInt}, Ptr{Float64}, Ref{BlasInt},
        #              Ptr{Float64}, Ptr{Float64}, Ref{BlasInt}, Ptr{BlasInt}),
        #             m, n, A, max(1,stride(A,2)), tau, work, lwork, info)
        #           if i == 1
        #               lwork = BlasInt(real(work[1]))
        #           end
        #       end
        #       A, tau
        #   end
        # # ===========================================================================


    # This performs a single iteration, and stores everything in the variables local to calc_LyapunovList()
    function iterate!()
        for i = 1:q
            #1. Add disorder to each site in the supercell and calculate the green's function G
            disordered_M .= M .+ Diagonal(rand(Uniform(-Wd/2,Wd/2),N))
            Mtemp .= E.*Im.-disordered_M;
            myinv!(Mtemp, G)

            #2. Calculate T_x using G and rewriting the Transfer equation in the SVD basis of J
            comp_overlap!(Gvv,(Vd,G,V))
            comp_overlap!(Gvw,(Wt,G,V))
            comp_overlap!(Gwv,(Vd,G,Wtd))
            comp_overlap!(Gww,(Wt,G,Wtd))

            assign_submat!(A, Gvv, 1, 1)
            assign_submat!(A, negId, 1, r+1)
            assign_submat!(A, Gvw, r+1, 1)
            assign_submat!(A, O, r+1, r+1)

            assign_submat!(B, O, 1, 1)
            assign_submat!(B, Gwv, 1, r+1)
            assign_submat!(B, negId, r+1, 1)
            assign_submat!(B, Gww, r+1, r+1)

            ldiv!(lu!(A),B);  # Computes A^{-1} B and stores it in B.
            Ttemp .= (-1).*B;

            #3.
              #case A: Starting a new q block
            if (i==1)
                T_x .= Ttemp

            #case B: Already inside a q block, take product of all T_x matrices
            else

                mul!(temp2, T_x, Ttemp)
                T_x .= temp2

                #Case C: Inside but at the end of the q block
                if i==q
                    R .= T_x*Q_prev  # T_x ----> T_x'= T_x*Q_(x-1), hold the result in R
                    F = qr!(R)
                    Q_prev = F.Q  #Q_prev stores Q_x for next iteration x+1
                end

            end #if-else
          end #for
    end


#  THE MAIN LOOP
# ==============================================================

    # Throw away the first q x Ntrans iterations
    Ntrans = 10;
    for x in (1:Ntrans)
       iterate!()
    end

    # Cumulatively store the subsequent iterations in λ_list
     λ_list = stdform(zeros(sizeT,1))
     Niter = Int64(floor(Nx/q))
     for x in (1: Niter)
        iterate!()
        λ_list .+= log.(abs.( view(R, diagind(R)) )) ./ Nx
    end

   return(λ_list,Q_prev)

end #FUNCTION
