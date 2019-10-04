#--------------------------------------------------INTRODUCTION--------------------------------------------------------------------
# main.jl takes one argument from the terminal i.e. number of workers to be created
#ARGS is the array that stores the arguments passed to the julia program (as STRINGs, hence they need to be parsed as Int)
# (TIP: REMEMBER TO ADD LIBRARIES WHICH ARE BEING IMPORTED IN THE PROGRAM TO A NEW ENVIRONMENT AND GET THE PROJECT.TOML FILE !!!)
#-------------------------------------------------------------------------------------------------------------------------


#----------------------------------------IMPORT LIBRARIES REQUIRED BY MASTER----------------------------------------------------------------


using Distributed, ClusterManagers,DelimitedFiles,LinearAlgebra

#-----------------------------------------DEFINE MASTER FUNCTIONS--------------------------------------------------------------------------------------

#=
Function to start 'nprocs' processes on 'machines'
=#

function start_workers(nprocs, machines)
j=1
for i in 1:nprocs
   if(j>length(machines)) 
     j=1
    end
   params = (exename=`nice -19 /vol/thp/share/julia-1.0.0-x86_64/bin/julia `, dir= dir_name )
   addprocs([(machines[j], 1)]; params...) #NOTE: SSH Manager is automatically called when you call addprocs() with an array
   j=j+1
 end

end


#-------------------------------------------READING INPUTS------------------------------------------------------------------------

#-------------(USER INPUT from terminal)---------------------
nprocs =  parse(Int, ARGS[1]) #number of workers 
start_index= parse(Int, ARGS[2]) #start at job index
stop_index= parse(Int, ARGS[3])  #stop at job index
#------------------------------------------------------------


dir_name= string(pwd())  #I/O directory= current working directory

println(string("THE INPUT/OUTPUT directory is ",dir_name))

job_list = readdlm(string(dir_name,"/job_list.txt"),'\t',skipstart=1)[start_index:stop_index,:]




#---------------------------------------LIST AVAILABLE MACHINES-----------------------------------------------------------------

machines=readdlm("/home/anegi/complist/available_complist.txt",' ') #list of available computers on the THP NETWORK by running cinit.sh

#---------------------------------------------------------------------------------------------------------------------------------




# one (m,W,Ly) = one job
njobs= stop_index-start_index+1 #number of jobs


println("Starting ", nprocs, " workers for jobs: ",start_index ," to ",stop_index, "...")
println("on THP CLUSTER :O!!\n")


start_workers(nprocs, machines) #workers are born 

println("Done.")
println("Started ",nworkers()," workers.\n")





#---------------------------------IMPORT FUNCTIONALITY REQUIRED @everywhere-----------------------------------------------------------------

@everywhere pushfirst!(Base.DEPOT_PATH, "/tmp/test.cache") #important!
@everywhere using Dates    
@everywhere using LinearAlgebra
@everywhere using DelimitedFiles
@everywhere using Statistics
@everywhere using Distributions

include("FindLyapunov.jl") #from the project directory where main.jl is
include("perform_job.jl")  #from the project directory where main.jl is
include("System_parameters.jl")  #from the project directory where main.jl is
#include(string(dir_name,"/System_parameters.jl")) # from the I/O directory

#--------------------------------------DO JOBS!!!!!!------------------------------------------------------------------------------

#creating directories for outputs
try
	mkdir(string(dir_name,"/l_list"))
	mkdir(string(dir_name,"/Q_prev"))
        mkdir(string(dir_name,"/R"))
catch;
end




#--------------------------------------DISTRIBUTE JOBS TO WORKERS----------------------------------------------------------------------

starting_at=now()

#Using the "LPT job scheduling algorithm" to distribute jobs among workers------------->


sorted_job_list=job_list[sortperm(job_list[:, 4],rev=true), :] #sort job_list in descending order of processing times (Ly)

load_per_worker=zeros(nprocs) #keep track of the amount of load on each worker

@sync for i in 1:size(job_list,1) #for a job in job_list between start and stop index

      #job parameters
      m=job_list[i,2]
      W=job_list[i,3]
      Ly=Int64.(job_list[i,4])
      system_scale=Int64.(job_list[i,5])
      Nx=system_scale*Ly

      min_index=argmin(load_per_worker) #pick the worker with the minimum load
      worker_for_job=min_index+1 #assign the job to that worker, remember that the worker index starts from 2
      load_per_worker[min_index]+=job_list[i,4] #update the worker load

      @async @spawnat worker_for_job perform_job(m,W,Ly,Nx,Int64.(job_list[i,1]),dir_name) #do job at the chosen worker

end


stopping_at=now()
time_diff= Dates.canonicalize(Dates.CompoundPeriod(Dates.DateTime(stopping_at) - Dates.DateTime(starting_at)))
println("ALL JOBS DONE in time $(time_diff) ! Now removing workers... please wait...")

#--------------------------remove workers-------------------------

for i in workers()
        rmprocs(i)
end

#------------------------------------------------------------------

println("ALL COMPLETE! Congratulations!!")
