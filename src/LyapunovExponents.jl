module LyapunovExponents

using LinearAlgebra
using Distributions
using Statistics

#-------------------------------------- FUNCTIONS to calculate Lyapunovs------------------------------------------------------------------------------------

include("dirac_model.jl")
include("hopping.jl")
include("utilities.jl")
include("transfer_matrix.jl")

export get_SystemParameters
export assign_J
export assign_M
export calculate_G
export get_LyapunovList

end