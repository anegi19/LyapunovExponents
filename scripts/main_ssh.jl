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
   params = (exename=`nice -19 /vol/thp/share/julia-1.0.0-x86_64/bin/julia `, dir= string(pwd()) )
   addprocs([(machines[j], 1)]; params...) #NOTE: SSH Manager is automatically called when you call addprocs() with an array
   j=j+1
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
