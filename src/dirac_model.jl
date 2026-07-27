"""
    get_SystemParameters(m)

Return the parameters of the two-dimensional Chern insulator model.

# Arguments

- `m`: Mass parameter controlling the topological phase.

# Returns

`(J_x, J_y, M, ϵ, p, q)`

where:

- `J_x` : hopping matrix in the x direction
- `J_y` : hopping matrix in the y direction
- `M`   : onsite Hamiltonian matrix
- `ϵ`   : probing energy
- `p`   : boundary condition flag (`0` open, `1` periodic)
- `q`   : number of transfer matrices grouped before QR decomposition

# Example

```julia
Jx,Jy,M,E,p,q = get_SystemParameters(1.0)

"""

function get_SystemParameters(m)

    σ_x = [0 1; 1 0]
    σ_y = [0 -1im; 1im 0]
    σ_z = [1 0; 0 -1]

    J_x = -(1im/2) * (σ_x - 1im*σ_z)
    J_y = 1im/2 * (σ_y + 1im*σ_z)

    M = (2 - m) * σ_z

    ϵ = 0.0
    p = 0
    q = 3

    return J_x, J_y, M, ϵ, p, q
end
