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


# Standard typecasting for matrices: Everything should be a complex matrix
@everywhere function stdform(mat)
    convert(Array{Complex{Float64},2},Matrix(mat))
end



@everywhere function get_LyapunovList(M::Array{Complex{Float64},2},V::Array{Complex{Float64},2},Xi::Array{Complex{Float64},2},Wt::Array{Complex{Float64},2},E::Float64,Ly::Int64,Nx::Int64,Wd::Float64,q::Int64)
#   INITIALIZATIONS
#  ==========================================
    N = size(M,1)
    r = size(Xi,1)
    sizeT = 2*r
    unit = 1.0+0.0*im;

    disordered_M = copy(M)
    Vd = V'
    Wtd = Wt'



#   PREALLOCATIONS
#  ==========================================
    # q = size of the blocks of QR
    # N = size of the M matrix = Num. of dof per supercell
    # r = rank of the 𝐉  Matrix
    # sizeT = 2r = size of transfer  matrix


    N = size(M,1)
    r = size(Xi,1)
    sizeT = 2*r
    unit = 1.0+0.0*im;

    disordered_M = copy(M)
    Vd = V'
    Wtd = Wt'


    # ===== N x N matrices =======
    Id_N = stdform(Diagonal(ones(N))) #Identity matrix of size: N x N
    G, Mtemp = copy(Id_N), copy(Id_N)


    # ===== r x r matrices =======
    O = stdform(Diagonal(zeros(r)))  # Zero matrix of size: r x r
    Id_r = stdform(Diagonal(ones(r)))  #Identity matrix of size: r X r
    negId = (-1).*Id_r;

    # Subblocks of the transfer matrix
    Gvv, Gvw, Gwv, Gww = copy(Id_r),copy(Id_r),copy(Id_r),copy(Id_r)


    # ===== 2r x 2r matrices =======
    Id_2r = stdform(Diagonal(ones(sizeT)))  #Identity matrix of size 2r X 2r
    T = copy(Id_2r)                         # Initialize the transfer matrix
    A, B = copy(Id_2r), copy(Id_2r)         # Auxilliaries reqd to compute T
    Tcur = copy(Id_2r)                      # Transfer matrix at the current step
    temp = copy(Id_2r)                      # Temporary variable to store products
    Q_prev, R = copy(Id_2r), copy(Id_2r)    # Variables to store QR decompositions



#   LOCAL FUNCTIONS
#  ==========================================

    # Memory-efficient matrix inverse computation
    # Inverts the matrix A and overwrites the result on Y
    function myinv!(A::Array{Complex{Float64},2}, Y::Array{Complex{Float64},2})
        Ylen=size(A,1);
        Y .= 0 .* A;
        @inbounds @simd for i in 1:Ylen
         Y[i,i] = 1.0;
        end
        ldiv!(lu!(A),Y)
    end


    # Define this to be "global" within a function call to calc_LyapunovList()
    temp_rN = stdform(zeros(r,N))
    # In-place multiplier for 3 nonsquare matrices, as needed to compute G_ab
    # Multiples the three (nonsquare) matrices in "list" and overwrites
    # the result on G_ab.
    function comp_overlap!(G_ab, list)
      mul!(temp_rN, list[1], list[2])
      mul!(G_ab, temp_rN, list[3])
    end


    # In-place submatrix assignments
    # Assigns the matrix elements of A to those of B (with dim B < dim A)
    # starting at indices (m,n).
    function assign_submat!(A::Array{Complex{Float64},2},B::Array{Complex{Float64},2},m::Int64,n::Int64)
     Blen = size(B,1)
     @inbounds @simd for j in n:(n+Blen-1)
         @inbounds for i in m:(m+Blen-1)
             A[i,j] = B[i-m+1, j-n+1];
         end
     end
    end


    # This performs a single iteration, and stores everything in the variables local to calc_LyapunovList()
    function iterate!()
        for i = 1:q
            # Add disorder and calculate the on-site green's function G
            if(Wd>0)
            	disordered_M .= M .+ Diagonal(rand(Uniform(-Wd/2,Wd/2),N))
	    else
 		disordered_M .= M
 	    end

            Mtemp .= E.*Id_N .- disordered_M;
            myinv!(Mtemp, G)

            # Calculate the submatrices needed to assemble the transfer matrix
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

            # Calculate the transfer matrix using the SVD basis of J
            ldiv!(lu!(A),B);  # Computes A^{-1} B and stores it in B.
            Tcur .= (-1).*B;

            if i==1         # Starting a new q block
                T .= Tcur
            else            # Already inside a q block, take product of all T matrices
                mul!(temp, T, Tcur)
                T .= temp
            end

            # At the end of the q block (possibly with q = 1)
            if i==q
                R .= T*Q_prev   # T ----> T'= T*Q_(x-1), hold the result in R
                F = qr!(R)
                Q_prev = F.Q    #Q_prev stores Q_x for next iteration x+1
            end

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
    for x in 1: Niter
        iterate!()
        λ_list .+= log.(abs.( view(R, diagind(R)) )) ./ Nx
    end

    return(λ_list,Q_prev,R)

end #FUNCTION
