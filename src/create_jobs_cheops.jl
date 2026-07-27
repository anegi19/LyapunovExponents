#=

Function to map each job information to its respective machine
=#
function map_jobs(njobs,m_list,W_list,Ly_list,system_scale)

	map= zeros(njobs,5)
	count=1
         
     for Ly in Ly_list
   		for m in m_list
      		     for W in W_list 
                                
	     		 map[count,1]= count #jobid 
	     		 map[count,2]= round(m,digits=6) # corresponding m
	      	         map[count,3]= round(W,digits=6) # corresponding W
              		 map[count,4]= Ly # corresponding Ly
                         map[count,5]= system_scale#workerid 
	      		 count+=1
			 
        		end
   		end
	end
  
return(map)
end


function computetime(Ly, scale)

    runtime = Int64(ceil(2e-6 * Ly^3 * scale))

    days=0
    hours = 0
    minutes = 0
    seconds = Int64.(runtime % 60)

    if runtime >= 60
        minutes = Int64.(floor( runtime/ 60))
    end

    if minutes >= 60
        hours = Int64.(floor(minutes / 60))
        minutes = Int64.(minutes % 60)
    end

    if hours >=24
        days = Int64.(floor(hours / 24))
        hours = Int64.(hours % 24)
    end
    
    if seconds>9
    seconds_str= "$seconds"
    else
    seconds_str= "0$seconds"
    end
    
    if minutes>9
    minutes_str= "$minutes"
    else
    minutes_str= "0$minutes"
    end
    
    if hours>9
    hours_str= "$hours"
    else
    hours_str= "0$hours"
    end
    
    if days>9
    days_str= "$days"
    else
    days_str= "0$days"
    end
    
    
    time_str= string(days_str,"-",hours_str,":",minutes_str,":",seconds_str)
    return(time_str)

end




#=

Function to generate cheops scripts
=#

function genscript(f,istart,iend,walltime)
    println(istart)
    println(f,"#!/bin/bash -l\n")
    println(f,"#SBATCH --ntasks=1")
    println(f,"#SBATCH --cpus-per-task=$ncpus")
    println(f,"#SBATCH --array=",istart,"-",iend)
    println(f,"#SBATCH --mem=1gb")
    println(f,"#SBATCH --time=",walltime)
    println(f,"#SBATCH --output=\"/scratch/vdwivedi/disorder/julia/runs/$projname/logs/run%a.log\"")
    println(f,"#SBATCH --job-name=\"$projname\"")
    println(f,"#SBATCH --mail-user=vdwivedi@uni-koeln.de")
    println(f,"#SBATCH --mail-type=BEGIN,END\n")
    println(f,"echo \"Starting. The current time is \" \$(date)")
    println(f,"module load julia")
    println(f,"echo -e \"Loaded Julia module\\n\"\n")
    println(f,"cd /scratch/vdwivedi/disorder/julia/runs/$projname")
    println(f,"julia  $codepath \${SLURM_ARRAY_TASK_ID}")
    println(f,"echo -e \"\\nDone. The current time is \" \$(date)")

end





using LinearAlgebra
using DelimitedFiles




#--------------generate JOB LIST ----------------




min_m=1.98
max_m=2.02
m_steps=41

min_W=5.85
max_W=6.05
W_steps=40

#m_list= LinRange(min_m,max_m,m_steps)
m_list=[0.5]
W_list=  LinRange(min_W,max_W,W_steps)

Ly_list=[5,7,8,10,14,16,20,25,28,32,40,50,56,64,80]
system_scale =100000

njobs= length(m_list)*length(W_list)*length(Ly_list) #number of jobs
job_list= map_jobs(njobs,m_list,W_list,Ly_list,system_scale) #create a job_list

filename=string(pwd(),"/job_list.txt") #creates job_list.txt in the working directory

open(filename, "w") do f      
    write(f,"jobID\tm\tW\tLy\tscale\n")
    writedlm(f,job_list)
end


#--------------generate JOB SCRIPTS FOR CHEOPS----------------

ncpus = 4
projname = "QExp_23"
codepath = "/home/vdwivedi/julia/cheops/instance.jl"

# NEED TO REWRITE

nscr = length(Ly_list)
jobsize = length(m_list)*length(W_list)

for i in 1:nscr
    walltime = computetime(Ly_list[i], system_scale)
    istart = (i-1)*jobsize + 1
    iend = i*jobsize
    scrname = string("jscr",i,".sh")
    scrfile = open(scrname, "w")
    genscript(scrfile,istart,iend,walltime)
    close(scrfile)
    println("Done writing ", scrname)
end

cur_dir = pwd()
try
	mkdir(string(cur_dir,"/logs"))
catch;
end

println("Done")
