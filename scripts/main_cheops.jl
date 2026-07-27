#--------------------------------------------------INTRODUCTION--------------------------------------------------------------------
# main.jl takes one argument from the terminal i.e. number of workers to be created
#ARGS is the array that stores the arguments passed to the julia program (as STRINGs, hence they need to be parsed as Int)
# (TIP: REMEMBER TO ADD LIBRARIES WHICH ARE BEING IMPORTED IN THE PROGRAM TO A NEW ENVIRONMENT AND GET THE PROJECT.TOML FILE !!!)
#-------------------------------------------------------------------------------------------------------------------------


#----------------------------------------IMPORT LIBRARIES REQUIRED BY MASTER----------------------------------------------------------------


using Distributed, ClusterManagers,DelimitedFiles,LinearAlgebra




#------------- -------------------------------------(USER INPUT from terminal)------------------------------------------
nprocs =  parse(Int, ARGS[1]) #number of workers 
start_index= parse(Int, ARGS[2]) #start at job index
stop_index= parse(Int, ARGS[3])  #stop at job index
#--------------------------------------------------------------------------------------------------------------------------------------------------

#-------------------------------------STARTING GIVEN NUMBER OF WORKERS--------------------------------------------------------------------------------------------




# one (m,W,Ly) = one job
njobs= stop_index-start_index+1 #number of jobs


println("Starting ", nprocs, " workers for jobs: ",start_index ," to ",stop_index, "...")
println("on CHEOPS CLUSTER :O!!\n")


addprocs(SlurmManager(nprocs)) #SlurmManager works for CHEOPS

println("Done.")
println("Started ",nworkers()," workers.\n")


#-------------------------------------------SETTING I/O Directory------------------------------------------------------------------------

@everywhere dir_name= string(pwd())  #I/O directory= current working directory

println(string("THE INPUT/OUTPUT directory is ",dir_name))


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

#Using "pmap" to distribute jobs among workers------------->

pmap(perform_job,start_index:stop_index);

stopping_at=now()
time_diff= Dates.canonicalize(Dates.CompoundPeriod(Dates.DateTime(stopping_at) - Dates.DateTime(starting_at)))
println("ALL JOBS DONE in time $(time_diff) ! Now removing workers... please wait...")

#--------------------------remove workers-------------------------

for i in workers()
        rmprocs(i)
end

#------------------------------------------------------------------

println("ALL COMPLETE! Congratulations!!")
