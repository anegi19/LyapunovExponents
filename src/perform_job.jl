
#=
Function to call worker 'i' to perform the job with jobID 'i' each job = one (m,W,Ly)
=#

@everywhere function perform_job(job_index::Int64)
        
	worker_id = myid()
        host_id = gethostname()

        #job details
        my_job = readdlm(string(dir_name,"/job_list.txt"),'\t',skipstart=1)[job_index,:]
        jobID=Int64.(my_job[1])       
        m=my_job[2]
        W=my_job[3]
        Ly=Int64.(my_job[4])
        system_scale=Int64.(my_job[5])
        Nx=system_scale*Ly


        start_time= now()
        println("Starting my job $(jobID) on $(host_id) at time $(start_time) ")
        
       
        #SYSTEM: CHERN INSULATOR

        #SYSTEM PARAMETERS: 

        J_x,J_y,M,ϵ,p,q = get_SystemParameters(m)
        
	𝐌= assign_M(M,J_y,Ly,p)
	𝐉,𝐕,𝚵,𝐖t=assign_J(J_x,Ly)


	λ_list,Q_prev,R=get_LyapunovList(𝐌,𝐕,𝚵,𝐖t,ϵ,Ly,Nx,W,q) # calculate the Lyapunov's for the given JOB data

        #write OUTPUT in files
        filename= string(dir_name,"/l_list/lyaps_",jobID)
        writedlm(filename,real(λ_list), ", ")
        filename= string(dir_name,"/Q_prev/Qprev_",jobID)
        writedlm(filename,Q_prev, ", ")
        filename= string(dir_name,"/R/R_",jobID)
        writedlm(filename,R, ", ")
	

        finish_time= now()
        println("Finished my job $(jobID) on $(host_id) at time $(finish_time) ")
        
        #update the JOB_RUN_LOG.txt file
        time_taken= Dates.canonicalize(Dates.CompoundPeriod(Dates.DateTime(finish_time) - Dates.DateTime(start_time)))

        filename=string(dir_name,"/JOB_RUN_LOG.txt")
        open(filename, "a") do f
             write(f,"$(jobID)\t$m\t$W\t$(Ly)\t $(Nx)\t$(worker_id)\t$host_id\t $time_taken\n")
        end 

       
        
        


end