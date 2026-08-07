# LyapunovExponents.jl

Julia package for calculating Lyapunov spectra of disordered tight-binding models using transfer-matrix methods [1].

---
## Introduction

This Julia package implements stabilized transfer-matrix calculations for obtaining the Lyapunov spectrum of disordered lattice systems. The systems are treated as quasi-one-dimensional strips with transverse system size ($L_y$) and longitudinal system size

$$
N_x = \mathrm{scale}\times L_y.
$$

For a given set of model parameters:

$$(m, W, L_y)$$

where:

- $m$ : system parameter
- $W$ : disorder strength
- $L_y$ : transverse system size

the transfer matrix is iterated along the longitudinal direction. Repeated QR decompositions are used to stabilize the numerical calculation and extract the Lyapunov spectrum

$$
\lambda_1,\lambda_2,\ldots,\lambda_{2r}
$$

The resulting Lyapunov exponents provide information about the localization properties of the system. In particular, the smallest positive Lyapunov exponent,


$$\lambda_{\min},$$

is related to the quasi-one-dimensional localization length through

$$
\xi \sim \frac{1}{\lambda_{\min}}.
$$

This allows the numerical results to be used to investigate localization, disorder-driven transitions, and finite-size scaling.

The calculations are designed for large-scale parameter sweeps and can be distributed across multiple CPUs or cluster nodes using Julia's `Distributed.pmap`.

---
## Results

### Example: Qi-Wu-Zhang Chern Insulator

As an example application, we consider the **Qi-Wu-Zhang (QWZ) model** [2], a minimal two-band tight-binding model describing a two-dimensional Chern insulator on a square lattice. The model consists of two orbitals per lattice site and is characterized by the Bloch Hamiltonian

$$
H(\mathbf{k}) =
\sin(k_x)\sigma_1
+
\sin(k_y)\sigma_2
+
(2-m-\cos(k_x)-\cos(k_y))\sigma_3 .
$$

Here, the Pauli matrices $\sigma_i$ act in the orbital space, while the parameter $m$ controls the band inversion and determines the topological phase of the system.

The QWZ model exhibits topological phase transitions as the mass parameter $m$ is varied. The bulk energy gap closes at high-symmetry points for

$$
m=0,2,4,
$$

where the Chern number changes. Between these gap-closing points, the system realizes Chern insulating phases with non-zero Chern number, while outside these regions the system is topologically trivial.

<p align="center">
  <img src="imgs/QWZ_model.png" width="800">
</p>


We study how disorder modifies the localization properties of the QWZ Chern insulator by calculating the Lyapunov spectrum using transfer-matrix methods. We consider two types of onsite disorder.

### 1. Anderson disorder

The conventional Anderson disorder is introduced by adding a random scalar potential,

$$
H_{\mathrm{dis}}=\sum_i w_i\sigma_0 ,
$$

where $w_i$ is independently sampled from a uniform distribution with

$$ \langle w_i\rangle =0,\qquad
\mathrm{Var}(w_i)=\frac{W^2}{12}.
$$

This disorder modifies the local chemical potential while preserving the orbital structure of the Hamiltonian.

### 2. Pseudomagnetic disorder

The pseudomagnetic disorder is introduced through a random mass term,
$$
H_{\mathrm{dis}}=\sum_i w_i\sigma_3 .
$$
This perturbation directly modifies the local mass term responsible for band inversion and therefore affects the topological properties of the system.

<p align="center">
  <img src="imgs/Slide3.PNG" width="800">
</p>

<p align="center">
  <img src="imgs/Slide4.PNG" width="800">
</p>

The calculated Lyapunov exponents can be used to calculate the conductance through the Landauer formula:

$$
g=\sum_i \mathrm{sech}^2(|\lambda_i N_x|),
$$

where ($N_x$) is the longitudinal system size and ($g$) is expressed in units of ($2e^2/h$).

For a clean topological Chern insulating phase, the conductance approaches $g=2$,corresponding to the two conducting edge channels, whereas for a trivial insulating phase,$g=0$.

By scanning the disorder strength ($W$) and the mass parameter ($m$), we map out the phase diagram of the disordered Chern insulator. The appearance of Lyapunov exponents approaching zero signals delocalized states in the bulk gap and identifies the topological phase boundary.

<p align="center">
  <img src="imgs/Slide5.PNG" width="800">
</p>

---

## Project Structure

```
LyapunovExponents/
│
├── Project.toml
├── README.md
│
├── src/
│   ├── LyapunovExponents.jl
│   ├── hopping.jl
│   ├── transfer_matrix.jl
│   └── System_parameters.jl
│
├── scripts/
│   ├── main_cheops.jl
│   ├── main_ssh.jl
│   └── perform_job.jl
│
├── jobs/
│   ├── create_jobs_cheops.jl
│   └── create_jobs_ssh.jl
│
├── bin/
│   └── job_list.txt
│
└── test/
    └── runtests.jl
```

---

# Installation

Clone the repository:

```bash
git clone <repository-url>
cd LyapunovExponents
```

Activate the Julia environment:

```bash
julia --project=.
```

Install dependencies:

```julia
using Pkg
Pkg.instantiate()
```

---

# Creating Jobs

Jobs are defined in `job_list.txt`.

Each row corresponds to one independent calculation:

```
jobID    m       W       Ly      scale
1        2.0     5.9     20      100000
2        2.0     6.0     20      100000
...
```

The job list can be generated using:

```
jobs/create_jobs_cheops.jl
```

or:

```
jobs/create_jobs_ssh.jl
```

The generated file is stored in:

```
bin/job_list.txt
```

---

# Running Calculations

## CHEOPS Cluster (SLURM)

Generate the job list and SLURM submission scripts:

```bash
julia --project=. jobs/create_jobs_cheops.jl
```

Submit the generated SLURM scripts.

Each SLURM task runs:

```bash
julia --project=. scripts/main_cheops.jl \
     num_workers \
     start_job_index \
     stop_job_index
```

where:

- `num_workers` = number of Julia workers created
- `start_job_index` = first job index
- `stop_job_index` = last job index

Example:

```bash
julia --project=. scripts/main_cheops.jl 8 1 100
```

This runs jobs `1`–`100` using 8 workers.

---

## SSH Cluster

For SSH-based distributed calculations:

```bash
julia --project=. scripts/main_ssh.jl \
     num_workers \
     start_job_index \
     stop_job_index
```

The available machines are supplied through the SSH worker configuration.

---

# Output

Results are written inside the `bin/` directory.

After a calculation:

```
bin/
│
├── l_list/
│   └── lyaps_<jobID>
│
├── Q_prev/
│   └── Qprev_<jobID>
│
├── R/
│   └── R_<jobID>
│
└── JOB_RUN_LOG.txt
```

## Lyapunov Spectrum

The file:

```
l_list/lyaps_<jobID>
```

contains the Lyapunov spectrum:

\[
\lambda_1,\lambda_2,\dots,\lambda_{2r}
\]

for the corresponding `(m, W, Ly)` parameter set.

## QR Data

The files:

```
Q_prev/
R/
```

store the final QR decomposition matrices used during transfer-matrix iteration.

---

# Parallelisation

The project uses:

```julia
Distributed.pmap
```

Jobs are dynamically assigned to workers:

```julia
pmap(job -> perform_job(job, bin_dir),
     start_index:stop_index)
```

Each worker:

1. Reads one row from `job_list.txt`
2. Constructs the system matrices
3. Calculates the Lyapunov spectrum
4. Writes output files
5. Records execution information in `JOB_RUN_LOG.txt`

---

# Testing

Run the package tests:

```bash
julia --project=. -e "using Pkg; Pkg.test()"
```

---

# Main Components

### `hopping.jl`

Constructs:

- hopping matrices
- clean onsite matrices
- block structures for the supercell

---

### `transfer_matrix.jl`

Computes the Lyapunov spectrum using:

- Green function construction
- transfer matrix iteration
- QR decomposition stabilisation

---

### `System_parameters.jl`

Defines model-specific matrices:


$ J_x, J_y, M $

and numerical parameters.

---

# Authors

Ankita Negi, Vatsal Dwivedi

Institute of Theoretical Physics, University of Cologne (2019)

---

# References

[1] Kunst, F. K., & Dwivedi, V. (2019).  
*Non-Hermitian systems and topology: A transfer-matrix perspective.*  
Physical Review B, 99(24).

DOI: https://doi.org/10.1103/physrevb.99.245116


[2] Qi, X.-L., Wu, Y.-S., and Zhang, S.-C.
Topological quantization of the spin Hall effect in two-dimensional paramagnetic semiconductors.
Physical Review B 74, 085308 (2006).

DOI: https://doi.org/10.1103/PhysRevB.74.085308
