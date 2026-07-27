"""
    assign_J(J_x, Ly)

Constructs the longitudinal hopping matrix and its reduced basis representation
using the singular value decomposition (SVD) of the hopping matrix `J_x`.

The hopping matrix of the full system is assumed to have a block diagonal
structure:

    J = BLOCK_DIAG(J_x, J_x, ..., J_x)

with `Ly` repeated blocks.

The SVD of the single-cell hopping matrix is

    J_x = v * Ξ * w'

where `Ξ` contains the singular values of `J_x`.

The corresponding matrices for the full system are constructed as

    J  = kron(I, J_x)
    V  = kron(I, v)
    Wt = kron(I, w')

where `I` is the `Ly × Ly` identity matrix.

# Arguments
- `J_x::Array{Complex{Float64},2}`:
    The hopping matrix of a single supercell.

- `Ly::Int64`:
    Number of sites (supercells) in the transverse direction.

# Returns
- `𝐉`:
    Full hopping matrix of the system.

- `𝐕`:
    Left singular-vector basis of the hopping matrix.

- `Xi`:
    Singular-value matrix representation.

- `𝐖t`:
    Transpose of the right singular-vector basis.

# Notes
The returned matrices are used to construct the transfer matrix in the
Lyapunov exponent calculation.
"""


function assign_J(J_x::Array{Complex{Float64},2},Ly::Int64)

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


"""
    assign_M(M, J_y, Ly, p)

Constructs the clean onsite matrix of the 2D system.

The returned matrix represents the onsite Hamiltonian of a supercell without
any disorder. Disorder is added later during the Lyapunov exponent calculation.

The matrix has the block tridiagonal structure

    𝐌 = BLOCK_DIAG(M, M, ..., M)
        + upper diagonal blocks J_y'
        + lower diagonal blocks J_y

For periodic boundary conditions (`p == 1`), additional corner blocks are
added:

    upper-right block  = J_y
    lower-left block  = J_y'

corresponding to transverse periodic coupling.

# Arguments
- `M::Array{Complex{Float64},2}`:
    Clean onsite Hamiltonian matrix of a single site/supercell.

- `J_y::Array{Complex{Float64},2}`:
    Transverse hopping matrix.

- `Ly::Int64`:
    Number of sites in the transverse direction.

- `p::Int64`:
    Boundary condition flag:
    - `0`: open boundary conditions (OBC)
    - `1`: periodic boundary conditions (PBC)

# Returns
- `𝐌::Array{Complex{Float64},2}`:
    The clean onsite matrix of the full supercell.

# Notes
This function only constructs the clean system matrix. Random onsite
disorder is introduced separately in `get_LyapunovList`.
"""

function assign_M(M::Array{Complex{Float64},2},J_y::Array{Complex{Float64},2},Ly::Int64,p::Int64)

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

