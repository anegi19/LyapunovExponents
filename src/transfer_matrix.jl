
"""
    get_LyapunovList(M, V, Xi, Wt, E, Ly, Nx, Wd, q)

Calculate the Lyapunov spectrum of a disordered two-dimensional system using
the transfer matrix method.

The system is divided into `Nx` longitudinal supercells, each containing `Ly`
sites in the transverse direction. For each supercell, diagonal disorder is
added to the onsite Hamiltonian, the Green's function is calculated, and the
transfer matrix is constructed in the singular-value basis of the hopping
matrix.

The Lyapunov exponents are obtained by multiplying transfer matrices along the
longitudinal direction and periodically applying QR decompositions for numerical
stability.

# Arguments

- `M::Array{ComplexF64,2}`:
    Clean onsite Hamiltonian matrix of one supercell.

- `V::Array{ComplexF64,2}`:
    Left singular-vector matrix from the SVD of the hopping matrix.

- `Xi::Array{ComplexF64,2}`:
    Singular-value matrix of the hopping matrix. The transfer matrix size is
    determined by `r = size(Xi,1)`.

- `Wt::Array{ComplexF64,2}`:
    Right singular-vector matrix from the SVD of the hopping matrix.

- `E::Float64`:
    Energy at which the Green's function is evaluated.

- `Ly::Int64`:
    Number of sites in the transverse direction.

- `Nx::Int64`:
    Number of supercells in the longitudinal direction.

- `Wd::Float64`:
    Disorder strength. The onsite disorder is sampled from a uniform
    distribution in the interval `[-Wd/2, Wd/2]`.

- `q::Int64`:
    Number of transfer matrices multiplied before each QR decomposition.

# Returns

- `λ_list`:
    Array containing the Lyapunov exponents
    `[λ₁, λ₂, ..., λ₂r]`.

- `Q_prev`:
    Final orthogonal matrix from the QR decomposition.

- `R`:
    Final upper triangular matrix from the QR decomposition.

# Notes

The Green's function is calculated as:

    G = (E*I - M)^(-1)

The transfer matrix is constructed from the projected Green's function blocks:

    Gvv = V' * G * V
    Gvw = Wt * G * V
    Gwv = V' * G * Wt'
    Gww = Wt * G * Wt'

Block QR decomposition is used to avoid numerical overflow during long
transfer-matrix multiplication.
"""


function get_LyapunovList(M::Array{Complex{Float64},2},V::Array{Complex{Float64},2},Xi::Array{Complex{Float64},2},Wt::Array{Complex{Float64},2},E::Float64,Ly::Int64,Nx::Int64,Wd::Float64,q::Int64)
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
