
"""
    stdform(mat)

Convert a matrix-like object into a dense `ComplexF64` matrix.

This function is used internally to ensure that all matrices entering
the transfer matrix calculation have a consistent type.

# Arguments

- `mat`: Any object convertible to a Julia matrix.

# Returns

A dense matrix of type `Matrix{ComplexF64}`.

# Example

```julia
A = stdform(Diagonal(ones(3)))
"""

function stdform(mat)
    convert(Array{Complex{Float64},2},Matrix(mat))
end
