#--------------------------------------------------INTRODUCTION--------------------------------------------------------------------
# main.jl takes one argument from the terminal i.e. number of workers to be created
#ARGS is the array that stores the arguments passed to the julia program (as STRINGs, hence they need to be parsed as Int)
# (TIP: REMEMBER TO ADD LIBRARIES WHICH ARE BEING IMPORTED IN THE PROGRAM TO A NEW ENVIRONMENT AND GET THE PROJECT.TOML FILE !!!)
#-------------------------------------------------------------------------------------------------------------------------


#----------------------------------------IMPORT LIBRARIES REQUIRED BY MASTER----------------------------------------------------------------


using Distributed, ClusterManagers, Dates




#------------- -------------------------------------(USER INPUT from terminal)------------------------------------------
nprocs =  parse(Int, ARGS[1]) #number of workers 
start_index= parse(Int, ARGS[2]) #start at job index
stop_index= parse(Int, ARGS[3])  #stop at job index
#--------------------------------------------------------------------------------------------------------------------------------------------------

#-------------------------------------STARTING GIVEN NUMBER OF WORKERS--------------------------------------------------------------------------------------------


# one (m,W,Ly) = one job
njobs= stop_index-start_index+1 #number of jobs

println("Number of jobs: ", njobs)
println("Starting ", nprocs, " workers for jobs: ",start_index ," to ",stop_index, "...")
println("on CHEOPS CLUSTER :O!!\n")


addprocs(SlurmManager(nprocs)) #SlurmManager works for CHEOPS

println("Done.")
println("Started ",nworkers()," workers.\n")


#-------------------------------------------SETTING I/O Directory------------------------------------------------------------------------

project_dir = dirname(@__DIR__)
bin_dir = joinpath(project_dir, "bin")

#println("Project directory: ", project_dir)
println("Data directory: ", bin_dir)


#---------------------------------IMPORT FUNCTIONALITY REQUIRED @everywhere-----------------------------------------------------------------

@everywhere pushfirst!(Base.DEPOT_PATH, "/tmp/test.cache") #important!
@everywhere begin 
	using Dates    
	using LinearAlgebra
	using DelimitedFiles
	using Statistics
	using Distributions
	using LyapunovExponents
	include(joinpath($project_dir,"scripts","perform_job.jl"))
end


#--------------------------------------DO JOBS!!!!!!------------------------------------------------------------------------------

#creating directories for outputs
mkpath(joinpath(bin_dir,"l_list"))
mkpath(joinpath(bin_dir,"Q_prev"))
mkpath(joinpath(bin_dir,"R"))

#--------------------------------------DISTRIBUTE JOBS TO WORKERS----------------------------------------------------------------------

starting_at=now()

#Using "pmap" to distribute jobs among workers------------->

pmap(job -> perform_job(job, bin_dir),
     start_index:stop_index)

stopping_at=now()
time_diff= Dates.canonicalize(Dates.CompoundPeriod(Dates.DateTime(stopping_at) - Dates.DateTime(starting_at)))
println("ALL JOBS DONE in time $(time_diff) ! Now removing workers... please wait...")

#--------------------------remove workers-------------------------

for i in workers()
        rmprocs(i)
end

#------------------------------------------------------------------

println("ALL COMPLETE! Congratulations!!")
