# nephonon

**nephonon** is a Fortran-based software package designed for calculating phonon properties and neutron scattering intensities. It supports force constants entered from Phonopy (via `FORCE_CONSTANTS` file) or directly generated from [Neuroevolution Potentials (NEPs)](https://github.com/brucefan1983/NEP_CPU) using an integrated interface.

## Features

- **Force Constant Calculation**: 
  - Read from Phonopy `FORCE_CONSTANTS` file.
  - Generate `FORCE_CONSTANTS` using NEPs (Neuroevolution Potentials) via finite differences (`gen2ndfc`).
- **Phonon Band Structure**: Calculate phonon dispersion relations along high-symmetry paths.
- **Density of States (DOS)**: Calculate phonon density of states using Gaussian smearing.
- **Neutron Scattering Intensity**:
  - **Single Crystal $S(\mathbf{Q},\omega)$**: Calculate coherent one-phonon dynamic structure factor.
  - **Powder $S(|Q|,\omega)$**: Calculate powder-averaged neutron scattering intensity.
- **Group Velocity**: Calculate phonon group velocities analytically.
- **Isosurface**: Calculate phonon frequency isosurfaces in reciprocal space.
- **LO-TO Splitting**: Support for non-analytic correction using Born effective charges and dielectric tensor.
- **Symmetry**: Enforce crystal symmetry on force constants.

## Physical Formulas

### 1. Dynamical Matrix
The dynamical matrix $D_{\alpha\beta}(\kappa\kappa'|\mathbf{q})$ is calculated as:

$$
D_{\alpha\beta}(\kappa\kappa'|\mathbf{q}) = \frac{1}{\sqrt{M_\kappa M_{\kappa'}}} \sum_{l'} \Phi_{\alpha\beta}(0\kappa, l'\kappa') e^{i\mathbf{q}\cdot(\mathbf{r}_{l'\kappa'} - \mathbf{r}_{0\kappa})}
$$

where $\Phi$ are the force constants, $M$ are atomic masses, and $\mathbf{r}$ are atomic positions.

### 2. Phonon Density of States (DOS)
The phonon DOS $g(\omega)$ is calculated using Gaussian smearing:

$$
g(\omega) = \frac{1}{N_q}\sum_{\mathbf{q},j}\frac{1}{\sqrt{\pi}\sigma}\exp[-(\frac{\omega - \omega_{\mathbf{q}j}}{\sigma})^2]
$$

where $\sigma$ is the smearing width (`DOS_SIGMA`).

### 3. Neutron Scattering Intensity $S(\mathbf{Q},\omega)$
The coherent one-phonon dynamic structure factor is calculated as:

$$
S(\mathbf{Q},\omega) \propto \sum_j \frac{n(\omega_{\mathbf{Q}j}) + 1}{\omega_{\mathbf{Q}j}} \left| F_j(\mathbf{Q}) \right|^2 \delta(E - \hbar\omega_{\mathbf{Q}j})
$$

where the dynamic structure factor $F_j(\mathbf{Q})$ is:

$$
F_j(\mathbf{Q}) = \sum_\kappa \frac{b_\kappa}{\sqrt{M_\kappa}} e^{-W_\kappa} (\mathbf{Q} \cdot \mathbf{e}_{\kappa,j}) e^{i\mathbf{Q}\cdot\mathbf{d}_\kappa}
$$

- $n(\omega)$: Bose-Einstein distribution factor.
- $b_\kappa$: Coherent neutron scattering length of atom $\kappa$.
- $W_\kappa$: Debye-Waller factor, $W_\kappa = \frac{1}{2} \langle (\mathbf{Q} \cdot \mathbf{u}_\kappa)^2 \rangle$.
- $\mathbf{e}_{\kappa,j}$: Phonon eigenvector.

## Units and Conventions
- Lattice vectors in `LATTICE_PARAMETERS` are in Angstrom.
- `ATOMIC_POSITIONS`:
  - `Direct`: fractional coordinates in the lattice basis (converted internally to Cartesian).
  - `Cartesian`: Cartesian coordinates in Angstrom.
- Internally, the dynamical-matrix solver returns angular frequencies in THz; most outputs are written as energies in meV.
- Q-points in `BANDS_STRUCTURE` are given as fractional coordinates in the reciprocal basis derived from `LATTICE_PARAMETERS`.
- The x‑axis of the `sqw_powder.dat` file is given in **$Å^{-1}$** (inverse Angstrom), i.e., absolute reciprocal‑space units.

## Installation

### Prerequisites
- **Fortran Compiler**: `ifort` (recommended) or `gfortran`.
- **C++ Compiler**: `icx` or `g++` (required for NEP interface).
- **Libraries**: MKL, BLAS, and LAPACK.
- **Build Tool**: `make`.

### Compilation
1. Edit the `Makefile` to set your compiler and library paths if necessary.
2. Run `make` in the `src` directory:
   ```bash
   cd nephonon/src
   make
   ```
   This will generate the executable in `src/` (typically `nephonon` on Linux systems or `nephonon.exe` on Windows systems).

### macOS Installation Notes
For macOS users who install GCC via Homebrew, the default `g++` and `gfortran` may be mismatched. To resolve this, we recommend explicitly setting the compilers in the `Makefile`:

```makefile
FC = /opt/homebrew/bin/gfortran
CXX = /usr/bin/g++
nephonon: $(CPP_OBJS) $(PHONON_OBJS)
        $(CXX) -o $@ $(PHONON_OBJS) $(CPP_OBJS) $(LDFLAGS) $(LIBS) \
        -L/opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current -lgfortran -lquadmath
```

### Verified Software Environment
| Compiler | Dynamic Link Library |
|----------|----------------------|
| g++ (GCC) 8.3.1; ifort (IFORT) 2021.5.0 | linux-vdso.so.1;libmkl_intel_lp64.so.2;libmkl_intel_thread.so.2;libmkl_core.so.2;libiomp5.so;libstdc++.so.6;libm.so.6;libpthread.so.0;libc.so.6;libgcc_s.so.1;libdl.so.2;librt.so.1;ld-linux-x86-64.so.2 |
| g++ (GCC) 8.3.1; ifort (IFORT) 2021.7.0 | linux-vdso.so.1;libmkl_intel_lp64.so.2;libmkl_intel_thread.so.2;libmkl_core.so.2;libiomp5.so;libstdc++.so.6;libm.so.6;libpthread.so.0;libc.so.6;libgcc_s.so.1;libdl.so.2;librt.so.1;ld-linux-x86-64.so.2 |
| Intel(R) oneAPI DPC++/C++ Compiler 2021.3.0; ifx (IFORT) 2021.3.0 Beta 20210619 | linux-vdso.so.1;libmkl_intel_lp64.so.1;libmkl_intel_thread.so.1;libmkl_core.so.2;libiomp5.so;libstdc++.so.6;libm.so.6;libpthread.so.0;libc.so.6;libgcc_s.so.1;libdl.so.2;librt.so.1;ld-linux-x86-64.so.2 |
| g++ (x86_64-win32-seh-rev0, Built by MinGW-Builds project) 15.2.0; GNU Fortran (x86_64-win32-seh-rev0, Built by MinGW-Builds project) 15.2.0 | ntdll.dll;KERNEL32.DLL; KERNELBASE.dll; apphelp.dll; ucrtbase.dll; libblas.dll; msvcrt.dll;liblapack.dll;libgcc_s_seh-1.dll;libgfortran-5.dll;libgfortran-5.dll;libgfortran-5.dll;ADVAPI32.dll;sechost.dll;RPCRT4.dll; libwinpthread-1.dll; libstdc++-6.dll; libquadmath-0.dll |

## Quick Start Example

1. **Prepare Input Files**:
   - `inp.control`: Main control file.
   - `FORCE_CONSTANTS`: Force constants (Phonopy format), or generated by NEPs when `gen2ndfc = .true.`.
   - `nep.txt`: Required when `gen2ndfc = .true.` (NEPs file, [see details in the official website](https://gpumd.org/)).
   - `inp.lotosplitting`: Required when `nonanalytic = .true.`.

2. **Run the Calculation**:
   `nephonon` reads `inp.control` from the current working directory. The only supported command-line options are help flags (other arguments are ignored).
   ```bash
   # From a working directory containing inp.control
   nephonon
   ```
   To print a built-in input template, run:
   ```bash
   nephonon -h
   ```

3. **Check Outputs**:
   - `phononband.dat`: Band structure data.
   - `phonondos.dat`: Density of states data.
   - `sqw_crystal.dat`: Single-crystal $S(\mathbf{Q},\omega)$ data (path mode).
   - `sqw_powder.dat`: Powder $S(|Q|,\omega)$ data.

## Detailed Documentation

### `inp.control` Input Parameters

The input file uses Fortran namelists. Key parameters include:

#### `&basic`
- `ntypes`: Number of atom types.
- `natoms`: Total number of atoms in the unit cell.
- `nsize`: Supercell dimensions (e.g., `3 3 3`).

#### `&inputph`
- **Calculation Switches**:
  - `gen2ndfc`: `.TRUE.` to calculate force constants using NEPs.
  - `dos`: `.TRUE.` to calculate DOS.
  - `band`: `.TRUE.` to calculate band structure.
  - `sqw_crystal`: `.TRUE.` to calculate single crystal $S(\mathbf{Q},\omega)$ along band paths.
  - `sqw_powder`: `.TRUE.` to calculate powder $S(|Q|,\omega)$.
  - `isosurface`: `.TRUE.` to calculate frequency isosurface.
  - `velocity`: `.TRUE.` to calculate group velocities.
  - `nonanalytic`: `.TRUE.` to include LO-TO splitting (requires `inp.lotosplitting`).
  - `fc_symmetry`: `.TRUE.` to symmetrize force constants.
- **System Info**:
  - `elements`: Array of element symbols (e.g., `'Na', 'Cl'`).
  - `nat`: Array of atom counts per type.

#### `&inputsqw` (for Neutron Scattering)
- `e_min`, `e_max`: Energy range (meV).
- `ne_bins`: Number of energy bins.
- `temperature`: Temperature in Kelvin.
- `e_smearing`: Energy broadening polynomial coefficients (FWHM model), converted internally to a Gaussian sigma.
- `q_smearing`: Q-smearing polynomial coefficients (FWHM model). Applied after powder averaging.
- `q_min`, `q_max`: $|Q|$ range for powder calculation.
- `dw_qmesh`: Q-mesh for Debye-Waller factor calculation.
- `lphase`: Whether to include phase factor $\exp(i \mathbf{Q}\cdot\mathbf{r})$.

#### Input Blocks
- `LATTICE_PARAMETERS`: 3 lattice vectors (one vector per line).
- `ATOMIC_POSITIONS`: Atomic positions. The next line is `Direct` or `Cartesian`.
- `DENSITY_OF_STATES`: Q-mesh for DOS (e.g., `20 20 20`). Required if `dos = .true.`.
- `DOS_SIGMA`: Base DOS smearing width (meV). Internally the code evaluates 10 widths: `dos_sigma * (1..10)`.
- `BANDS_STRUCTURE`: Path definitions (start frac-q, end frac-q, npoints). Required if `band = .true.`; also used by `sqw_crystal = .true.`.
- `ISOSURFACE`: Q-mesh for isosurface. Required if `isosurface = .true.`.
- `Displace_DELTA`: Displacement distance for finite difference (used when `gen2ndfc = .true.`).

### Output Files
- `FORCE_CONSTANTS`: Generated when `gen2ndfc = .true.` (Phonopy format).
- `phonondos.dat`: DOS (meV) for multiple smearings.
- `phonondosvelocity.dat`: Group velocities on DOS q-mesh (if `velocity = .true.`).
- `phonondosvect.dat`: Eigenvectors on DOS q-mesh (if `eigenvector = .true.`).
- `phononband.dat`: Band structure energies (meV).
- `phononbandvelocity.dat`: Band group velocities (if `velocity = .true.`).
- `phononbandvect.dat`: Band eigenvectors (if `eigenvector = .true.`).
- `phononsurface.fs`: Isosurface values in FermiSurfer format.
- `sqw_crystal.dat`: Single-crystal $S(\mathbf{Q},\omega)$ along band paths.
- `sqw_powder.dat`: Powder-averaged $S(|Q|,\omega)$.

## Examples
Example inputs are provided under `example/`. To run an example, execute `src/nephonon` in that example directory so it can find `inp.control` and required inputs:
```bash
cd example/Copper
../../src/nephonon
```

On Windows, use:
```powershell
cd example\Copper
..\..\windowsexe\nephonon.exe
```

## How to Cite

If you use **nephonon** in your research, please cite:
> [NEPHONON: An Efficient Phonon Calculator Based on Neuroevolution Potentials, Peng-Fei Liu, Jianbo Zhu, Xi Chen, Jingyu Li, Yongsheng Zhang*, and Junrong Zhang*, Comput. Phys. Commun.](https://markdown.com.cn "Markdown 教程网站")

## Contribution Guide

We welcome contributions!
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/NewFeature`).
3. Commit your changes (`git commit -m 'Add NewFeature'`).
4. Push to the branch (`git push origin feature/NewFeature`).
5. Open a Pull Request.

## Acknowledgements
Special thanks to the open-source projects and funds.
