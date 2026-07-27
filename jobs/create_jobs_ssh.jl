using DelimitedFiles

include("slurm_utils.jl")


# ---------------- SYSTEM PARAMETER SWEEP ----------------

m_list = LinRange(-0.05, 0.05, 41)

W_list = [0.0]
# W_list = LinRange(0.0, 2.0, 20)

Ly_list = [5,7,8,10,14,16,20,25,28,32,40,50,56,64,80,100]

system_scale = 100000


# ---------------- GENERATE JOB LIST ----------------

njobs = length(m_list) * length(W_list) * length(Ly_list)

job_list = map_jobs(
    njobs,
    m_list,
    W_list,
    Ly_list,
    system_scale
)


project_dir = dirname(@__DIR__)   # parent directory of scripts/
filename = joinpath(project_dir, "bin", "job_list.txt") #creates job_list.txt in the /bin directory

open(filename, "w") do f      
    write(f,"jobID\tm\tW\tLy\tscale\n")
    writedlm(f,job_list)
end


println("Generated $njobs jobs")
println("Saved job list to $filename")

