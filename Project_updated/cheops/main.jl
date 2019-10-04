#--------------------------------------------------INTRODUCTION--------------------------------------------------------------------
# main.jl takes one argument from the terminal i.e. number of workers to be created
#ARGS is the array that stores the arguments passed to the julia program (as STRINGs, hence they need to be parsed as Int)
# (TIP: REMEMBER TO ADD LIBRARIES WHICH ARE BEING IMPORTED IN THE PROGRAM TO A NEW ENVIRONMENT AND GET THE PROJECT.TOML FILE !!!)
#-------------------------------------------------------------------------------------------------------------------------


#----------------------------------------IMPORT LIBRARIES REQUIRED BY MASTER----------------------------------------------------------------


using Distributed, ClusterManagers,DelimitedFiles,LinearAlgebra

#-----------------------------------------DEFINE MASTER FUNCTIONS--------------------------------------------------------------------------------------

#=
Function to map each job information to its respective machine
=#
function map_jobs(njobs,m_list,W_list,Ly_list)

	map= zeros(njobs,5)
	count=1
	for Ly in Ly_list
   		for m in m_list
      		     for W in W_list
	     		 map[count,1]= count #jobid 
	      		 #map[count,2]= #workerid 
	     		 map[count,3]= m # corresponding m
	      	         map[count,4]= W # corresponding W
              		 map[count,5]= Ly # corresponding Ly
	      		 count+=1
        		end
   		end
	end
  
return(map)
end


#-------------------------------------------READING INPUTS------------------------------------------------------------------------

dir_name= string(pwd())  #I/O directory= current working directory

println(string("THE INPUT/OUTPUT directory is ",dir_name))

m_list = readdlm(string(dir_name,"/m_list.txt"),' ')
W_list = readdlm(string(dir_name,"/W_list.txt"),' ')
Ly_list = Int.(readdlm(string(dir_name,"/Ly_list.txt"),' '))
system_scale = Int.(readdlm(string(dir_name,"/scale.txt"),' '))[1]



#------------------------------------ START given number of WORKERS-------------------------------------------------------------------------


nprocs = length(ARGS) < 1 ? 1 : parse(Int, ARGS[1]) #number of workers(USER INPUT)

# one (m,W,Ly) = one job
njobs= length(m_list)*length(W_list)*length(Ly_list) #number of jobs


println("starting ", nprocs, " workers for ", njobs, " jobs...")
println("on CHEOPS CLUSTER :O!!")


addprocs(SlurmManager(nprocs))  #SlurmManager works for CHEOPS

println("Started ",nworkers()," workers\n")
println("Done.\n")


#--------------------------------------MAP and DISTRIBUTE JOB TO WORKERS----------------------------------------------------------------------

#Using the "LPT job scheduling algorithm" to distribute jobs among workers------------->


Ly_list=sort(Ly_list, rev=true, dims=1) #sort List in descending order of processing times

job_list= map_jobs(njobs,m_list,W_list,Ly_list) #create a job_list

load_per_worker=zeros(nprocs) #keep track of the amount of load on each worker

for i in 1:size(job_list,1) #for each job in job_list
     min_index=argmin(load_per_worker) #pick the worker with the minimum load
     job_list[i,2]=min_index+1 #assign the job to that worker, remember that the worker index starts from 2
     load_per_worker[min_index]+=job_list[i,5] #update the worker load
end

filename=string(pwd(),"/JOB(#,w_ID,m,W,Ly).txt")
writedlm(filename,job_list)




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
catch;
end

#start job
@sync for i in 1:size(job_list,1)
      workerID=Int64.(job_list[i,2])
      m=job_list[i,3]
      W=job_list[i,4]
      Ly=Int64.(job_list[i,5])
      Nx=system_scale*Ly
      @async @spawnat workerID perform_job(m,W,Ly,Nx,i,dir_name) 
end

println("JOB COMPLETE! Congratulations!!")


#--------------------------remove workers-------------------------
for i in workers()
        rmprocs(i)
end

#------------------------------------------------------------------
