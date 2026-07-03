!=============================================================================
! Global variables module for phonon calculations
!
! This module defines all global variables used throughout the program.
! It includes basic system parameters, calculation flags, and phonon-specific
! data (lattice vectors, force constants, reciprocal-space grids, etc.).
!=============================================================================
Module variables
  Implicit None
!===========================================================================
! Basic system parameters
!===========================================================================
  Integer (Kind=4) :: ntypes ! Number of different atom types in the system
  Integer (Kind=4) :: natoms ! Total number of atoms in the unit cell
  Integer (Kind=4) :: nsize(3) ! Supercell size: (nx, ny, nz)
  Integer (Kind=4), Allocatable :: nat(:) ! Number of atoms of each type (ntypes)

!===========================================================================
! Atomic data
!===========================================================================
  Character (Len=3), Allocatable :: elements(:) ! Element symbols for each type (ntypes)

!===========================================================================
! Calculation flags
!===========================================================================
  Logical :: gen2ndfc ! If .TRUE., generate second-order force constants (FC2) from NEP.
  Logical :: nonanalytic ! If .TRUE., include LO-TO splitting (non-analytic correction).
  Logical :: dos ! If .TRUE., calculate phonon density of states
  Logical :: band ! If .TRUE., calculate phonon band structure
  Logical :: eigenvector ! If .TRUE., output eigenvectors to files
  Logical :: velocity ! If .TRUE., calculate phonon group velocity
  Logical :: fc_symmetry ! If .TRUE., apply symmetry to force constants
  Logical :: isosurface ! If .TRUE., calculate phonon isosurface data.
  Logical :: sqw_crystal ! If .TRUE., calculate single-crystal S(Q,E).
  Logical :: sqw_powder ! If .TRUE., calculate powder-averaged S(|Q|,E).
!===========================================================================
! Phonon calculation parameters
!===========================================================================
  Integer (Kind=4) :: nbands ! Number of phonon bands (typically 3*natoms)

!===========================================================================
! Crystal structure
!===========================================================================
  Real (Kind=8) :: latvec(3, 3) ! Primitive lattice vectors [Angstrom]
  Real (Kind=8) :: vol ! Volume of primitive unit cell [Angstrom^3]
  Real (Kind=8) :: rlatvec(3, 3) ! Reciprocal lattice vectors [1/Angstrom]
  Real (Kind=8), Allocatable :: positions(:, :) ! Atomic positions (3, natoms) [Angstrom, Cartesian]

!===========================================================================
! LO-TO splitting parameters (for polar materials)
!===========================================================================
  Real (Kind=8) :: epsilon(3, 3) ! Dielectric tensor (3x3 matrix)
  Real (Kind=8), Allocatable :: born(:, :, :) ! Born effective charge tensors (3, 3, natoms)

!===========================================================================
! Force constants and masses
!===========================================================================
  Real (Kind=8), Allocatable :: masses2(:) ! Atomic masses for each atom (natoms), in amu.
! Short-range real-space force constants.
! Dimension: (natoms, 3, nsize(1), nsize(2), nsize(3), natoms, 3).
! Convention: force on atom i (component alpha) from atom j in cell (ix,iy,iz)
! (component beta).
  Real (Kind=8), Allocatable :: fc_short(:, :, :, :, :, :, :)

!===========================================================================
! Generate 2nd Force Constants related variables
!=========================================================================== 
  Real (Kind=8) :: displace_delta

!===========================================================================
! DOS related variables
!===========================================================================  
  Integer (Kind=4) :: dos_qmesh(3) ! q-mesh for DOS calculation.
  Real (Kind=8), Allocatable :: dos_omega(:) ! DOS energy grid (meV).
  Real (Kind=8), Allocatable :: dos_value(:) ! DOS values for the default smearing width.
  Real (Kind=8) :: dos_sigma = 1.D0 ! Base Gaussian smearing width for DOS (meV).

!===========================================================================
! Band structure related variables
!===========================================================================  
  Integer (Kind=4) :: nband_paths ! Number of band-structure path segments.
  Real (Kind=8), Allocatable :: band_paths(:, :, :) ! (3, 2, npaths): start/end points in fractional coords.
  Integer (Kind=4), Allocatable :: band_npoints(:) ! Number of q-points per path segment.

!===========================================================================
! Isosurface related variables
!===========================================================================    
  Integer (Kind=4) :: isosurface_qmesh(3) ! q-mesh for isosurface calculation.

!===========================================================================
! Neutron scattering related variables
!=========================================================================== 
! Control parameters
  Real (Kind=8) :: e_min = 0.D0
  Real (Kind=8) :: e_max = 10.D0
  Integer (Kind=4) :: ne_bins = 1000

  Real (Kind=8) :: temperature = 300.D0
  Integer (Kind=4) :: dw_qmesh(3) = [ 20, 20, 20 ] ! q-mesh for Debye-Waller / RMSD calculation.

  Logical :: lphase = .False. ! If .TRUE., include exp(i Q·r) phase factors in S(Q,E).

! Resolution function parameters
  Real (Kind=8) :: e_smearing(5) = (/ 1.17741D0, 0.D0, 0.D0, 0.D0, 0.D0 /)
  Real (Kind=8) :: q_smearing(5) = 0.D0

! Powder calculation parameters
  Real (Kind=8) :: q_min = 0.D0
  Real (Kind=8) :: q_max = 10.D0
  Integer (Kind=4) :: nq_bins = 100
  Integer (Kind=4) :: npts_sphere = 100
  Character (Len=32) :: sampling = 'golden' ! Direction sampling method for powder averaging.

! Arrays for scattering properties
  Real (Kind=8), Allocatable :: coh_b2(:) ! Coherent scattering length [fm] (natoms)
  Real (Kind=8), Allocatable :: scatt_xs2(:) ! Scattering cross section [barn] (natoms)
  Real (Kind=8), Allocatable :: abs_xs2(:) ! Absorption cross section [barn] (natoms)

  Real (Kind=8) :: crlatvec(3, 3)

! Results and intermediates
  Real (Kind=8), Allocatable :: armsd(:, :) ! RMSD for each atom and Cartesian component (3, natoms).
  Real (Kind=8), Allocatable :: sqwsum(:, :) ! Accumulated S(Q,E): (ne_bins, nq).
  Real (Kind=8), Allocatable :: omega(:, :) ! Phonon energies along q-list: (nq, nbands).
  Real (Kind=8), Allocatable :: cqlist(:, :) ! Q points in Cartesian coordinates: (3, nq).
  Real (Kind=8), Allocatable :: qlist(:, :) ! Q points in conventional fractional coordinates: (3, nq).
  Real (Kind=8), Allocatable :: pqlist(:, :) ! Q points in primitive fractional coordinates: (3, nq).
  Real (Kind=8), Allocatable :: qdist(:) ! Cumulative distance along a Q path: (nq).
  Integer (Kind=4), Allocatable :: elist(:) ! Optional mapping of q-point indices: (nq).
  Integer (Kind=4) :: nqtot ! Total number of Q points in the current list.
  Complex (Kind=8), Allocatable :: eigenvec(:, :, :) ! Phonon eigenvectors: (nq, nbands, nbands).
End Module variables
