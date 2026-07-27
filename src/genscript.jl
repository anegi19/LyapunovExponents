# using DelimitedFiles, LinearAlgebra

ncpus = 4
projname = "test"
codepath = "/home/vdwivedi/julia/cheops/instance.jl"

# NEED TO REWRITE
data = [14 100; 20 100; 28 100]
nscr = size(data,1)
jobsize = 200

function computetime(Ly, scale)
    runtime = Int64(ceil(5e-7 * Ly^3.5 * scale))
    days=0
    hours = 0
    minutes = 0
    seconds = Int64.(sec % 60)

    if sec >= 60
        minutes = Int64.(floor(sec / 60))
    end

    if minutes >= 60
        hours = Int64.(floor(minutes / 60))
        minutes = Int64.(minutes % 60)
    end

    if hours >=24
        days = Int64.(floor(hours / 24))
        hours = Int64.(hours % 24)
    end
    
    if seconds>10
    seconds_str= "$seconds"
    else
    seconds_str= "0$seconds"
    end
    
    if minutes>10
    minutes_str= "$minutes"
    else
    minutes_str= "0$minutes"
    end
    
    if hours>10
    hours_str= "$hours"
    else
    hours_str= "0$hours"
    end
    
    if days>10
    days_str= "$days"
    else
    days_str= "0$days"
    end
    
    
    time_str= string(days_str,"-",hours_str,":",minutes_str,":",seconds_str)
    return(time_str)
end




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
    println(f,"echo -e \"\\nDone. The current time is \" \$(date)\"")
end


for i in 1:nscr
    walltime = computetime(data[i,1], data[i,2])
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
