
#using LinearAlgebra
using DelimitedFiles

include("slurm_utils.jl")


#--------------generate JOB LIST ----------------


min_m=1.98
max_m=2.02
m_steps=41

min_W=5.85
max_W=6.05
W_steps=40

m_list= LinRange(min_m,max_m,m_steps)
#m_list=[0.5]
W_list=  LinRange(min_W,max_W,W_steps)

Ly_list=[5,7,8,10,14,16,20,25,28,32,40,50,56,64,80]
system_scale =100000

njobs= length(m_list)*length(W_list)*length(Ly_list) #number of jobs
job_list= map_jobs(njobs,m_list,W_list,Ly_list,system_scale) #create a job_list


project_dir = dirname(@__DIR__)   # parent directory of scripts/
filename = joinpath(project_dir, "bin", "job_list.txt") #creates job_list.txt in the /bin directory

open(filename, "w") do f      
    write(f,"jobID\tm\tW\tLy\tscale\n")
    writedlm(f,job_list)
end


#--------------generate JOB SCRIPTS FOR CHEOPS----------------

ncpus = 4
projname = "QExp_23"
codepath = joinpath(pwd(),"main_cheops.jl")


nscr = length(Ly_list)
jobsize = length(m_list)*length(W_list)

for i in 1:nscr
    walltime = computetime(Ly_list[i], system_scale)
    istart = (i-1)*jobsize + 1
    iend = i*jobsize
    scrname = string("jscr",i,".sh")
    scrfile = open(scrname, "w")
    genscript(scrfile,istart,iend,walltime)
    close(scrfile)
    println("Done writing ", scrname)
end

cur_dir = pwd()
try
	mkdir(string(cur_dir,"/logs"))
catch;
end

println("Done")
