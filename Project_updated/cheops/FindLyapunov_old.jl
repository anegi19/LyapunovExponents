#-------------------------------------- FUNCTIONS to calculate Lyapunovs------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------
#=
Function to construct and return the Hopping matrix 𝐉 and its Singular Value Decomposition,
given that there are Ly sites in the supercell and
𝐉 = BLOCK_Matrix( J_x, repeated N times )
--------------------------------------------------
If SVD of J_x = v.Ξ.w' 

(where Ξ = diagonal matrix with Singular Values of J_x along its diagonal in descending order)

SVD of 𝐉 = 𝐕.𝚵.𝐖t 

such that:

𝐕= BLOCK_Matrix(v, repeated N times)
𝚵= BLOCK_Matrix(Ξ, repeated N times)
𝐖t= BLOCK_Matrix(w', repeated N times)
---------------------------------------------------

=#





@everywhere function assign_J(J_x::Array{Complex{Float64},2},Ly::Int64)
   
    𝐈=Diagonal(ones(Ly))
    
    F= svd(J_x)
    v=F.U[:,1]
    w=F.V[:,1]
    
    𝚵=𝐈
    𝐕=kron(𝐈,v)
    𝐖t=kron(𝐈,w')
    𝐉=kron(𝐈,J_x)
    
    return(𝐉,𝐕,𝚵,𝐖t)   

end


#-----------------------------------------------------------------------------------------------------------------------


#=
Function to construct and return the 'clean' on-site matrix 𝐌,
given that there are Ly sites in the supercell and

𝐉 = BLOCK_Matrix( M, J_y', J_y : repeated Ly times along 0,-1 and 1 diagonal respectively)

=#


@everywhere function assign_M(M::Array{Float64,2},J_y::Array{Complex{Float64},2},Ly::Int64,p::Int64)
   
       𝐌=Array{Complex{Float64},2}
       𝐈=Diagonal(ones(Ly))
    	
       𝐈_up= diagm(1 => ones(Ly-1))
       𝐈_down= diagm(-1 => ones(Ly-1))
    
       𝐌= kron(𝐈,M)+ kron(𝐈_up,J_y')+kron(𝐈_down,J_y)
   
       if(p==1) #pbc=ON
              𝐈_PBCup = diagm((Ly-1) => ones(1))
              𝐈_PBCdown = diagm(-(Ly-1) => ones(1))
              𝐌+=kron(𝐈_PBCup,J_y)+kron(𝐈_PBCdown,J_y')
       end
       return(𝐌)
end


#-----------------------------------------------------------------------------------------------------------------------


#=
Function to add diagonal disorder to the Hamiltonian, taken from a uniform (box) distribution of width Wd. 

=#

@everywhere function add_Disorder(Wd::Float64,𝐌::Array{Complex{Float64},2})
    
    return(𝐌+Diagonal(rand(Uniform(-Wd/2,Wd/2),size(𝐌,1))))
    
end



#-----------------------------------------------------------------------------------------------------------------------

#=
Function to calculate and return the propogator/Green's function 𝐆 at energy ϵ.

=#
@everywhere function calculate_G(𝐌::Array{Complex{Float64},2},ϵ::Float64) 
    
    𝐈=Diagonal(ones(size(𝐌,1)))
    𝐆=(ϵ*𝐈-𝐌)\𝐈
    return(𝐆)
end


#--------------------------------------------------------------------------------------------------------------------------


#=

Function to calculate and store (1) λ_list (Lyapunov spectrum) (2)Last value of Qprev at a given value of (m,W) of a 2D disordered system 
with (x,y) dimensions = (Nx,Ly)

-----------------------------------------------------------------------------------------------------------------------
Inputs: 
         𝐌 :: Array{Float64},2},Array{Complex{Float64},2} ::On site (clean) matrix of a supercell
     𝐕,𝚵,𝐖t:: Array{Float64},2},Array{Complex{Float64},2} ::SVD OF 𝐉
         Ly :: Int64                                       ::Number of sites in a supercell (transverse length of the system)
         Nx :: Int64                                       ::Number of supercells (longitudinal length of the system) 
         Wd :: Float64                                     ::Disorder Strength
          q :: Int64                                       ::Number of QR decomposition steps to skip

------------------------------------------------------------------------------------------------------------------------ 
Outputs: returns
   
       λ_list :: Array{Float64,1}                           ::[ λ_1, λ_2,...λ_2r]  in descending order     
last value of Q:: Array{Float64,1}                      
-------------------------------------------------------------------------------------------------------------------------  


=#

@everywhere function get_LyapunovList(𝐌,𝐕,𝚵,𝐖t,ϵ::Float64,Ly::Int64,Nx::Int64,Wd::Float64,q::Int64)
     
 
     #q =size of the blocks of QR
     
     #r= rank of the 𝐉  Matrix
     #size of 𝐓  matrix = 2r X 2r
    
     r=size(𝚵,1)
    
     𝐈=Diagonal(ones(r)) #Identity matrix of size: r X r
     𝐎=Diagonal(zeros(r)) # Zero matrix of size: r x r
     
     #initialize
     T_x=Diagonal(ones(2*r))
     Q_prev=Diagonal(ones(2*r)) 
     λ_list=zeros(2*r,1) 


    for x in (1: Nx) #move along x direction
       

        #Calculating Transfer matrix T_x for the m-th slice/supercell:
    
            #1. Add disorder to each site in the supercell and calculate the green's function 𝐆
        
     	    disordered_𝐌=add_Disorder(Wd,𝐌)
          	           𝐆=calculate_G(disordered_𝐌,ϵ)  
        
            #2. Calculate T_x using 𝐆 and rewriting the Transfer equation in the SVD basis of 𝐉
        
              #𝐕'=𝐕t ;𝐕 and 𝐕t are Hermitian conjugates.
              #𝐖t'=𝐖 ;𝐖 and 𝐖t are Hermitian conjugates.
      
            	                𝐀=[𝐕'*𝐆*𝐕*𝚵  -𝐈 ; 𝐖t*𝐆*𝐕*𝚵 𝐎]
            	                 𝐁=[𝐎 𝐕'*𝐆*𝐖t'*𝚵 ; -𝐈 𝐖t*𝐆*𝐖t'*𝚵]
         
                #NOTE: 𝐀, 𝐁 are sparse arrays and needs to be converted to a matrix before computing T_x= A^(-1)*B
       
        
            #3. 
              #case A: Starting a new q block
              if (x%q==1)
            
                   T_x= -Matrix(𝐀)\Matrix(𝐁)

              #case B: Already inside a q block, take product of all T_x matrices
              else 

                   T_x*= -Matrix(𝐀)\Matrix(𝐁) 
                   
                   #Case C: Inside but at the end of the q block 
                   if (x%q)==0 
       
                          T_x=T_x*Q_prev # T_x ----> T_x'= T_x*Q_(x-1)
       
                          F=qr(T_x) #Now do QR decomposition of the block T_x' matrix
                                 
                         # if(x>100)
                            λ_list +=log.(abs.(diag(F.R)))/Nx 
                         # end
                         
                          Q_prev=F.Q  #Q_prev stores Q_x for next iteration x+1
            
                     end 

        
               end #if-else   
            

        
      end #for


   return(λ_list,Q_prev)



  
end #FUNCTION
    
