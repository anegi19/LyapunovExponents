#--------------------------------------------------INTRODUCTION--------------------------------------------------------------------
# main.jl takes one argument from the terminal i.e. number of workers to be created
#ARGS is the array that stores the arguments passed to the julia program (as STRINGs, hence they need to be parsed as Int)
# (TIP: REMEMBER TO ADD LIBRARIES WHICH ARE BEING IMPORTED IN THE PROGRAM TO A NEW ENVIRONMENT AND GET THE PROJECT.TOML FILE !!!)
#-------------------------------------------------------------------------------------------------------------------------


#----------------------------------------IMPORT LIBRARIES REQUIRED BY MASTER----------------------------------------------------------------


using Distributed, ClusterManagers, Dates
#-----------------------------------------DEFINE MASTER FUNCTIONS--------------------------------------------------------------------------------------

"""
    start_workers(nprocs, machines)

Start `nprocs` Julia workers distributed over the available SSH machines.
"""
function start_workers(nprocs, machines)

    j = 1

    for i in 1:nprocs

        if j > length(machines)
            j = 1
        end

        params = (
            exename=`nice -19 /vol/thp/share/julia-1.0.0-x86_64/bin/julia`,
            dir=pwd()
        )

        addprocs([(machines[j], 1)]; params...)

        j += 1
    end

end



#------------- -------------------------------------(USER INPUT from terminal)------------------------------------------
nprocs =  parse(Int, ARGS[1]) #number of workers 
start_index= parse(Int, ARGS[2]) #start at job index
stop_index= parse(Int, ARGS[3])  #stop at job index
#--------------------------------------------------------------------------------------------------------------------------------------------------

#---------------------------------------LIST AVAILABLE MACHINES-----------------------------------------------------------------

machines=readdlm("/home/anegi/complist/available_complist.txt",' ') #list of available computers on the THP NETWORK by running cinit.sh

#-----------------------------------------START WORKERS----------------------------------------------------------------------------------------


println("Starting ", nprocs, " workers for jobs: ",start_index ," to ",stop_index, "...")
println("on THP CLUSTER :O!!\n")


start_workers(nprocs, machines) #workers are born 

println("Done.")
println("Started ",nworkers()," workers.\n")


#-------------------------------------------SETTING I/O Directory------------------------------------------------------------------------

project_dir = dirname(@__DIR__)
bin_dir = joinpath(project_dir, "bin")

println("Data directory: ", bin_dir)


#---------------------------------IMPORT FUNCTIONALITY REQUIRED @everywhere-----------------------------------------------------------------

@everywhere begin

    using Dates
    using DelimitedFiles
    using LinearAlgebra
    using Statistics
    using Distributions

    using LyapunovExponents
     
    include(joinpath(project_dir,"scripts","perform_job.jl"))

end

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
