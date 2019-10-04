

@everywhere function perform_testjob(job_index::Int64)
       
	worker_id = myid()
        host_id = gethostname()

        my_job = readdlm(string(dir_name,"/job_list.txt"),'\t',skipstart=1)[job_index,:]
        jobID=my_job[1]        
        m=my_job[2]
        W=my_job[3]
        Ly=Int64.(my_job[4])
        system_scale=Int64.(my_job[5])
        Nx=system_scale*Ly
       
        start_time= now()
        println("starting my job $(jobID) on $(host_id) at time $(start_time) ")
       

        println("My (m,W,L,Nx,jobID) is ", m, " ", W," ", Ly," ",Nx," ",jobID)
	
        sleep(2);

        finish_time= now()
        println("Finished my job $(jobID) on $(host_id) at time $(finish_time) ")
        
        time_taken= Dates.canonicalize(Dates.CompoundPeriod(Dates.DateTime(finish_time) - Dates.DateTime(start_time)))

        filename=string(dir_name,"/JOB_RUN-MAP.txt")
        open(filename, "a") do f
             write(f,"$(jobID)\t$m\t$W\t$(Ly)\t $(Nx)\t$(worker_id)\t$host_id\t $time_taken\n")
        end 

       
        
        


end