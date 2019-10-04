#=
Function to call worker 'i' to perform the job with jobID 'i' each job = one (m,W,Ly)
=#

@everywhere function perform_job(m::Float64,W::Float64,Ly::Int64,Nx::Int64,jobID::Int64,dir_name::String)

        #NOTE: WORKER'S ID = myid()
     
        println("starting my job $(jobID) at $(gethostname()) on time $(now()) ")
       
        #SYSTEM: CHERN INSULATOR

        #SYSTEM PARAMETERS: 
        J_x,J_y,M,ϵ,p,q = get_SystemParameters(m)
        
	𝐌= assign_M(M,J_y,Ly,p)
	𝐉,𝐕,𝚵,𝐖t=assign_J(J_x,Ly)


	λ_list,Q_prev=get_LyapunovList(𝐌,𝐕,𝚵,𝐖t,ϵ,Ly,Nx,W,q)
	filename = string(dir_name,"/l_list/l(m,W,Ly)=",jobID )
        writedlm(filename,λ_list, ", ")
        filename = string(dir_name,"/Q_prev/Q(m,W,Ly)=",jobID )
        writedlm(filename,Q_prev, ", ")
	
        println("finishing my job $(jobID) at $(gethostname()) on time $(now()) ")


end