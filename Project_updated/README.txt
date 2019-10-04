

HOW TO USE THIS PROJECT TO CALCULATE LYAPUNOV EXPONENTS--->

1. CREATE an EMPTY "Project Directory".
2. COPY all files from this directory into the Project Directory.
3. CREATE an I/O Directory with input files a)m_list.txt b)W_list.txt c)Ly_list.txt d)scale.txt
4. CD to the I/O Directory
5. CALL julia --project="PATH/TO/PROJECT/DIRECTORY" "PATH/TO/PROJECT/DIRECTORY/main.jl" num_workers
   where num_workers = number of workers you want to create in the cluster.