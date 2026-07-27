# ==========================================================
# Utilities for generating SLURM job scripts
# ==========================================================

using DelimitedFiles


"""
    map_jobs(njobs, m_list, W_list, Ly_list, system_scale)

Generate a job table assigning a unique job ID to every combination of
parameters `(m, W, Ly)`.

# Arguments
- `njobs::Int`: Total number of jobs expected. Usually:
  `length(m_list) * length(W_list) * length(Ly_list)`
- `m_list`: List of mass parameters.
- `W_list`: List of disorder strengths.
- `Ly_list`: List of transverse system sizes.
- `system_scale`: Longitudinal scaling factor used to determine `Nx`.

# Returns
A matrix with columns:

1. `jobID`       : unique job identifier
2. `m`           : mass parameter
3. `W`           : disorder strength
4. `Ly`          : transverse system size
5. `system_scale`: scaling factor for longitudinal size

The rows define independent SLURM jobs.
"""
function map_jobs(njobs, m_list, W_list, Ly_list, system_scale)

    job_map = zeros(njobs, 5)

    count = 1

    for Ly in Ly_list
        for m in m_list
            for W in W_list

                job_map[count,1] = count #job-ID
                job_map[count,2] = round(m, digits=6)
                job_map[count,3] = round(W, digits=6)
                job_map[count,4] = Ly
                job_map[count,5] = system_scale

                count += 1
            end
        end
    end

    if count-1 != njobs
        error("Number of generated jobs does not match njobs")
    end

    return job_map
end



"""
    computetime(Ly, scale)

Estimate required SLURM walltime.

The current estimate is based on the empirical scaling:

    runtime ∝ Ly^3 * scale

Returns:
    String in SLURM time format:
    DD-HH:MM:SS
"""
function computetime(Ly, scale)

    runtime = Int64(ceil(2e-6 * Ly^3 * scale))

    days = runtime ÷ (24*3600)
    hours = (runtime % (24*3600)) ÷ 3600
    minutes = (runtime % 3600) ÷ 60
    seconds = runtime % 60

    return string(
        lpad(days,2,"0"), "-",
        lpad(hours,2,"0"), ":",
        lpad(minutes,2,"0"), ":",
        lpad(seconds,2,"0")
    )

end



"""
    genscript(filename, istart, iend, walltime)

Generate a SLURM array-job script.

Arguments:
- filename: output shell script name
- istart: first SLURM array index
- iend: last SLURM array index
- walltime: requested SLURM runtime

"""
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
