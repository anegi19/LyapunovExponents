#=

Function to map each job information to its respective machine
=#
function map_jobs(njobs,m_list,W_list,Ly_list,system_scale)

	map= zeros(njobs,5)
	count=1
   		for m in m_list
      		     for W in W_list
                        for Ly in Ly_list
	     		 map[count,1]= count #jobid 
	     		 map[count,2]= round(m,digits=3) # corresponding m
	      	         map[count,3]= round(W,digits=3) # corresponding W
              		 map[count,4]= Ly # corresponding Ly
                         map[count,5]= system_scale#workerid 
	      		 count+=1
        		end
   		end
	end
  
return(map)
end


using LinearAlgebra
using DelimitedFiles
m_list= LinRange(-0.5,0.5,5)
W_list=  LinRange(1,8,14)
Ly_list=[10,14,20,28,40,56]
system_scale =100

njobs= length(m_list)*length(W_list)*length(Ly_list) #number of jobs
job_list= map_jobs(njobs,m_list,W_list,Ly_list,system_scale) #create a job_list

filename=string(pwd(),"/job_list.txt") #creates job_list.txt in the working directory

open(filename, "w") do f      
    write(f,"jobID\tm\tW\tLy\tscale\n")
    writedlm(f,job_list)
end
