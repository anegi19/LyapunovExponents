#=

Function to map each job information to its respective machine
=#
function map_jobs(njobs,m_list,W_list,Ly_list,system_scale)

	map= zeros(njobs,5)
	count=1
   	for Ly in Ly_list	
      		for W in W_list 
			for m in m_list
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


using LinearAlgebra
using DelimitedFiles

min_m=-0.05
max_m=0.05
m_steps=41

min_W=0.0
max_W=2.0
W_steps=20

m_list= LinRange(min_m,max_m,m_steps)
W_list=[0.0]
#W_list=  LinRange(min_W,max_W,W_steps)

Ly_list=[5,7,8,10,14,16,20,25,28,32,40,50,56,64,80,100]
system_scale =100000

njobs= length(m_list)*length(W_list)*length(Ly_list) #number of jobs
job_list= map_jobs(njobs,m_list,W_list,Ly_list,system_scale) #create a job_list

filename=string(pwd(),"/job_list.txt") #creates job_list.txt in the working directory

open(filename, "w") do f      
    write(f,"jobID\tm\tW\tLy\tscale\n")
    writedlm(f,job_list)
end
