using Distributed
using DelimitedFiles
using Dates
#using Socket

using LyapunovExponents

"""
    perform_job(job_index, dir_name)

Execute a single Lyapunov exponent calculation job.

Each job corresponds to one parameter set `(m, W, Ly)` stored in
`job_list.txt`. The function constructs the clean system matrices,
calculates the Lyapunov spectrum, saves the results, and records the
execution details.

# Arguments

- `job_index::Int64`:
    Row index of the job in `job_list.txt`.

- `dir_name::String`:
    Directory containing input files and output folders.

# Output

Writes:
- `l_list/lyaps_<jobID>`
- `Q_prev/Qprev_<jobID>`
- `R/R_<jobID>`

and appends execution information to:
- `JOB_RUN_LOG.txt`

No value is returned.
"""

function perform_job(job_index::Int64, dir_name::String)
        
	worker_id = myid()
        host_id = gethostname()

        # Read job parameters
        my_job = readdlm(
                joinpath(dir_name, "job_list.txt"),
                '\t',
                skipstart=1
        )[job_index, :]        
        jobID=Int64.(my_job[1])       
        m=my_job[2]
        W=my_job[3]
        Ly=Int64.(my_job[4])
        system_scale=Int64.(my_job[5])
        Nx=system_scale*Ly

        start_time= now()
        println("Starting my job $(jobID) on $(host_id) at time $(start_time) ")
        
       
        #Construct system

        J_x,J_y,M,ϵ,p,q = get_SystemParameters(m)   
	𝐌= assign_M(M,J_y,Ly,p)
	𝐉,𝐕,𝚵,𝐖t=assign_J(J_x,Ly)

        #Calculate Lyapunov spectrum
	λ_list,Q_prev,R=get_LyapunovList(𝐌,𝐕,𝚵,𝐖t,ϵ,Ly,Nx,W,q) 

        #Save Output
        filename= string(dir_name,"/l_list/lyaps_",jobID)
        writedlm(filename,real(λ_list), ", ")
        filename= string(dir_name,"/Q_prev/Qprev_",jobID)
        writedlm(filename,Q_prev, ", ")
        filename= string(dir_name,"/R/R_",jobID)
        writedlm(filename,R, ", ")
	

        finish_time= now()
        println("Finished my job $(jobID) on $(host_id) at time $(finish_time) ")
        
        #Append the JOB_RUN_LOG.txt file
        time_taken= Dates.canonicalize(Dates.CompoundPeriod(Dates.DateTime(finish_time) - Dates.DateTime(start_time)))
        filename=string(dir_name,"/JOB_RUN_LOG.txt")
        open(filename, "a") do f
             write(f,"$(jobID)\t$m\t$W\t$(Ly)\t $(Nx)\t$(worker_id)\t$host_id\t $time_taken\n")
        end 

        return nothing


end