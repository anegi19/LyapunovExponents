
#THE DIVISION OF jobs among WORKERS is done by STATIC JOB SCHEDULING BY LPT algorithm 


HOW TO USE THIS PROJECT TO CALCULATE LYAPUNOV EXPONENTS--->

1. CREATE an EMPTY "Project Directory".
2. COPY all files from the "/thp" or "/cheops" directory into this Project Directory.
3. CREATE an I/O Directory
4. COPY or CREATE a job_list.txt file (using create_jobs.jl) in the I/O directory. (jobID,m,W,Ly,Nx)
5. CD to the I/O Directory.
6. CALL julia --project="PATH/TO/PROJECT/DIRECTORY" "PATH/TO/PROJECT/DIRECTORY/main.jl" num_workers start_job_index stop_job_index
   where num_workers = number of workers to be given to this particular julia process that does jobs from start_job_index to stop_job_index in the job_list.txt