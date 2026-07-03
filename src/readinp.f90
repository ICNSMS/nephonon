!=============================================================================
! Input parser module for phonon calculations
!
! This module provides routines to read and parse input files:
!   - inp.control: Main input file with crystal structure and parameters
!   - FORCE_CONSTANTS: Force constants file (Phonopy format)
!   - inp.lotosplitting: LO-TO splitting data (optional)
!
! Supports:
!   - DOS calculation setup
!   - Band structure path definition
!   - Isosurface calculation parameters
!   - Neutron scattering inputs
!=============================================================================

Module readinp
  Implicit None
  Private
  Public :: input_parser, read2fc, readborn

Contains

!===========================================================================
! Read and parse the control/input file
!
! This subroutine:
!   1. Reads basic parameters (ntypes, natoms, nsize) from namelist
!   2. Reads calculation options (dos, band, etc.) from namelist
!   3. Reads crystal structure (lattice vectors, atomic positions)
!   4. Reads calculation-specific sections (DOS mesh, band paths, etc.)
!   5. Calculates reciprocal lattice vectors
!   6. Sets atomic masses from periodic table
!   7. Reads LO-TO splitting data if needed
!
! Input file format: See help output for detailed format
!===========================================================================
  Subroutine input_parser
    Use variables, Only: ntypes, natoms, nsize, elements, nat, gen2ndfc, dos, band, &
                         eigenvector, velocity, nonanalytic, isosurface, &
                         fc_symmetry, sqw_crystal, sqw_powder, e_min, e_max, ne_bins, &
                         temperature, dw_qmesh, lphase, e_smearing, q_smearing, q_min, &
                         q_max, nq_bins, npts_sphere, nbands, positions, &
                         masses2, coh_b2, scatt_xs2, abs_xs2, dos_qmesh, displace_delta, &
                         isosurface_qmesh, nband_paths, band_paths, &
                         band_npoints, dos_sigma, latvec, rlatvec, vol, sampling
    Use constants, Only: periodic_table, atomic_masses, pi, eps5, scatt_length, &
                         scatt_total, scatt_absorp
    Use func, Only: cross_prod

    Implicit None

! Loop indices
    Integer (Kind=4) :: ii, jj, kk ! General loop indices
    Integer (Kind=4) :: istat ! I/O status
    Integer (Kind=4) :: ipath ! Index for band paths

! Atomic data
    Integer (Kind=4), Allocatable :: zid(:) ! Atomic numbers from periodic table

! Input file handling
    Character (Len=10) :: coord_type ! Coordinate type: "Direct" or "Cartesian"
    Character (Len=100) :: buffer ! Buffer for reading file lines

! Namelist definitions for Fortran namelist I/O
    Namelist /basic/    ntypes, natoms, nsize
    Namelist /inputph/  elements, nat, gen2ndfc, dos, band, eigenvector, velocity, &
                        nonanalytic, isosurface, fc_symmetry, sqw_crystal, sqw_powder
    Namelist /inputsqw/ e_min, e_max, ne_bins, e_smearing, q_smearing, temperature, dw_qmesh, lphase, &
                        q_min, q_max, nq_bins, npts_sphere, sampling

! Initialize default values
    coord_type = 'Direct' ! Default to fractional coordinates

! Read the basic namelist
    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Starting reading control and basic files ...                    '
    Write (*, '(a)') '================================================================'

! Read inp.control
    Open (1, File='inp.control', Status='old')
    Read (1, Nml=basic)
    nbands = 3*natoms
    Write (*, '(a,i0)') '   Number of atom types: ', ntypes
    Write (*, '(a,i0)') '        Number of atoms: ', natoms
    Write (*, '(a,i0)') ' Number of phonon bands: ', nbands
    Write (*, '(3(a,i0))') '         Supercell size: ', nsize(1), ' x ', nsize(2), ' x ', nsize(3)

    If (ntypes<1 .Or. natoms<1) Then
      Write (*, '(a)') 'Error: ntypes, natoms must be >= 1.'
      Stop
    End If
    If (natoms<ntypes) Then
      Write (*, '(a)') 'Error: natoms must be >= ntypes.'
      Stop
    End If
    If (any(nsize<1)) Then
      Write (*, '(a)') 'Error: all components of nsize must be >= 1.'
      Stop
    End If

    Allocate (elements(ntypes))
    Allocate (nat(ntypes))
    Allocate (positions(3,natoms))
    Allocate (masses2(natoms))
    Allocate (coh_b2(natoms))
    Allocate (scatt_xs2(natoms))
    Allocate (abs_xs2(natoms))

! Set defaults
    gen2ndfc = .False.
    dos = .False.
    band = .False.
    velocity = .False.
    eigenvector = .False.
    nonanalytic = .False.
    fc_symmetry = .False.    
    isosurface = .False.
    sqw_crystal = .False.
    sqw_powder = .False.
    nband_paths = 0

! Read the inputph namelist
    Write (*, '(a)')
    Read (1, Nml=inputph)
    Write (*, '(a)') 'Calculation options:'
    Write (*, '(a,L2)') '     Force Constants calculation:', gen2ndfc
    Write (*, '(a,L2)') '   Density of states calculation:', dos
    Write (*, '(a,L2)') '      Band structure calculation:', band
    Write (*, '(a,L2)') '          Isosurface calculation:', isosurface
    Write (*, '(a,L2)') '      S(Q,E)-weighted dispersion:', sqw_crystal
    Write (*, '(a,L2)') '                 Powder S(|Q|,E):', sqw_powder
    Write (*, '(a,L2)') '         Eigenvector calculation:', eigenvector
    Write (*, '(a,L2)') '      Group Velocity calculation:', velocity
    Write (*, '(a,L2)') '  LO-TO splitting (non-analytic):', nonanalytic
    Write (*, '(a,L2)') '         Force Constant Symmetry:', fc_symmetry

! Initialize inputsqw defaults
    e_min = 0.D0
    e_max = 10.D0
    ne_bins = 1000
    e_smearing = (/ 1.17741D0, 0.D0, 0.D0, 0.D0, 0.D0 /)
    q_smearing = 0.D0
    temperature = 300.D0
    dw_qmesh = (/ 20, 20, 20 /)

    If (sqw_crystal .Or. sqw_powder) Then
! Read inputsqw
      Rewind (1)
      Read (1, Nml=inputsqw, Iostat=istat)
      If (istat/=0) Then
        Write (*, '(a)') 'Warning: inputsqw namelist not found. Using defaults.'
      End If
    End If

    If (.Not. (gen2ndfc .Or. dos .Or. band .Or. isosurface .Or. sqw_crystal .Or. sqw_powder)) Then
      Write (*, '(a)') 'Error: one of gen2ndfc, dos, band, isosurface, or sqw must be true.'
      Stop
    End If
    Write (*, *)

! Read crystal structure and calculation blocks
    Rewind (1)
    Do While (.True.)
      Read (1, '(A)', Iostat=istat) buffer
      If (istat/=0) Exit
      If (index(buffer,'LATTICE_PARAMETERS')/=0) Then
        Do ii = 1, 3
          Read (1, *, Iostat=istat) latvec(:, ii)
        End Do
      End If
      If (index(buffer,'ATOMIC_POSITIONS')/=0) Then
        Read (1, *, Iostat=istat) coord_type
        coord_type = adjustl(coord_type)
        Do ii = 1, natoms
          Read (1, *, Iostat=istat) positions(:, ii)
        End Do
      End If
      If (index(buffer,'DENSITY_OF_STATES')/=0) Then
        If (.Not. dos) Then
          Write (*, '(a)') 'Warning: DENSITY_OF_STATES found but dos = .FALSE.'
        End If
        Read (1, *, Iostat=istat) dos_qmesh(1), dos_qmesh(2), dos_qmesh(3)
      End If
      If (index(buffer,'ISOSURFACE')/=0) Then
        If (.Not. isosurface) Then
          Write (*, '(a)') 'Warning: ISOSURFACE found but isosurface = .FALSE.'
        End If
        Read (1, *, Iostat=istat) isosurface_qmesh(1), isosurface_qmesh(2), isosurface_qmesh(3)
        If (istat/=0) Then
          Write (*, '(a)') 'Error in reading isosurface q-mesh'
          Stop
        End If
      End If
      If (index(buffer,'BANDS_STRUCTURE')/=0) Then
        If (.Not. band .And. .Not. sqw_crystal) Then
          Write (*, '(a)') 'Warning: BANDS_STRUCTURE found but band = .FALSE. and sqw_crystal = .FALSE.'
        End If
        ! Allocate and read band paths
        Read (1, *) nband_paths
        Allocate (band_paths(3,2,nband_paths), band_npoints(nband_paths))
        Do ipath = 1, nband_paths
          Read (1, *, Iostat=istat) band_paths(:, 1, ipath), band_paths(:, 2, ipath), band_npoints(ipath)
          If (istat/=0) Then
            Write (*, '(a)') 'Error reading band paths'
            Stop
          End If
        End Do
      End If
      If (index(buffer,'DOS_SIGMA')/=0) Then
        If (.Not. dos) Then
          Write (*, '(a)') 'Warning: DOS_SIGMA found but dos = .FALSE.'
        End If
        Read (1, *, Iostat=istat) dos_sigma
      End If

      If (index(buffer,'Displace_DELTA')/=0) Then
        If (.Not. gen2ndfc) Then
          Write (*, '(a)') 'Warning: Displace_DELTA found but gen2ndfc = .false.'
        End If
        Read (1, *, Iostat=istat) displace_delta
      End If

    End Do
    Close (1)
    Write (*, '(a)') 'Read the inp.control successfully.'

! convert lattice basis to cartesian basis if coord_type(1) is 'D' or 'd'
    If (coord_type(1:1)=='D' .Or. coord_type(1:1)=='d') Then
      positions = matmul(latvec, positions)
    Else If (coord_type(1:1)/='C' .And. coord_type(1:1)/='c') Then
      Write (*, '(a)') 'Error: unknown atomic coordinate type.'
      Stop
    End If

! calculate the reciprocal lattice and volume of unit cell
    Do ii = 1, 3
      jj = mod(ii, 3) + 1
      kk = mod(jj, 3) + 1
      Call cross_prod(latvec(:,jj), latvec(:,kk), rlatvec(:,ii))
    End Do
    vol = abs(dot_product(latvec(:,1),rlatvec(:,1)))
    rlatvec = 2.D0*pi*rlatvec/vol
!write(*,*) "Unit cell volume:", vol, "Angstrom^3"
    Write (*, *)

! set atomic masses
    Allocate (zid(ntypes))
    Do ii = 1, ntypes
! find the positions in periodic table
      jj = 1
      Do While (jj<=size(periodic_table))
        If (elements(ii)==periodic_table(jj)) Then
          zid(ii) = jj
          Exit
        End If
        jj = jj + 1
      End Do
      If (jj==(size(periodic_table)+1)) Then
        Write (*, '(a)') 'Error: specified elements not in periodic table'
        Stop
      End If
    End Do

! Set atomic masses and scattering properties directly from periodic table
    kk = 0
    Do ii = 1, ntypes
      Do jj = 1, nat(ii)
        kk = kk + 1
        masses2(kk) = atomic_masses(zid(ii))
        If (sqw_crystal .Or. sqw_powder) Then
          coh_b2(kk) = scatt_length(zid(ii))
          scatt_xs2(kk) = scatt_total(zid(ii))
          abs_xs2(kk) = scatt_absorp(zid(ii))
        Else
          coh_b2(kk) = 0.D0
          scatt_xs2(kk) = 0.D0
          abs_xs2(kk) = 0.D0
        End If
      End Do
    End Do
    Deallocate (zid)
  End Subroutine input_parser

!===========================================================================
! Read FORCE_CONSTANTS file in Phonopy format
!
! This subroutine:
!   1. Reads force constants from FORCE_CONSTANTS file
!   2. Converts from Phonopy's supercell indexing to unit cell indexing
!   3. Weights force constants with atomic masses (mass-reduced form)
!   4. Converts units from eV/(Angstrom^2*amu) to THz^2
!
! File format (Phonopy):
!   Line 1: Total number of atoms in supercell
!   For each atom pair (i, j):
!     Line: i j
!     3 lines: Force constant matrix (3x3)
!
! Output: fc_short - Mass-weighted force constants in THz^2
!===========================================================================  
  Subroutine readborn
    Use variables, Only: natoms, born, epsilon, fc_symmetry
    Use symmetrization, Only: enforce_charge_neutrality

    Implicit None
    Integer (Kind=4) :: istat
    Integer (Kind=4) :: ii, jj

! Initialize nonanalytic and born to default values
    Allocate (born(3,3,natoms))
    born = 0.D0
    epsilon = 0.D0
    epsilon(1, 1) = 1.D0
    epsilon(2, 2) = 1.D0
    epsilon(3, 3) = 1.D0

! Read LO-TO splitting data if nonanalytic is enabled
    Open (2, File='inp.lotosplitting', Status='old', Iostat=istat)
    If (istat/=0) Then
      Write (*, '(a)') 'Error: inp.lotosplitting not found but nonanalytic = .TRUE.'
      Stop
    End If

! Read dielectric tensor (3x3 matrix, 3 lines)
    Do ii = 1, 3
      Read (2, *, Iostat=istat) epsilon(ii, 1), epsilon(ii, 2), epsilon(ii, 3)
      If (istat/=0) Then
        Write (*, '(a,i0)') 'Error reading dielectric tensor from inp.lotosplitting at line ', ii
        Stop
      End If
    End Do

! Read BORN effective charge tensor for each atom (3 lines per atom)
    Do ii = 1, natoms
      Do jj = 1, 3
        Read (2, *, Iostat=istat) born(jj, 1, ii), born(jj, 2, ii), born(jj, 3, ii)
        If (istat/=0) Then
          Write (*, '(2(a,i0))') 'Error reading BORN tensor for atom ', ii, 'at line ', 3 + 3*(ii-1) + jj
          Stop
        End If
      End Do
    End Do

    Close (2)
    Write (*, '(a)') 'Read the inp.lotosplitting successfully.'

! Enforce charge neutrality if symmetry is requested
    If (fc_symmetry) Then
      Call enforce_charge_neutrality()
    End If
    Write (*, '(a)')
  End Subroutine readborn

!===========================================================================
! Read FORCE_CONSTANTS file in Phonopy format
!
! This subroutine:
!   1. Reads force constants from FORCE_CONSTANTS file
!   2. Converts from Phonopy's supercell indexing to unit cell indexing
!   3. Weights force constants with atomic masses (mass-reduced form)
!   4. Converts units from eV/(Angstrom^2*amu) to THz^2
!
! File format (Phonopy):
!   Line 1: Total number of atoms in supercell
!   For each atom pair (i, j):
!     Line: i j
!     3 lines: Force constant matrix (3x3)
!
! Output: fc_short - Mass-weighted force constants in THz^2
!===========================================================================
  Subroutine read2fc()
    Use variables, Only: natoms, nsize, masses2, fc_short, fc_symmetry
    Use symmetrization, Only: symmetrize_force_constants
    Use constants, Only: dm2thz

    Implicit None

! File reading
    Integer (Kind=4) :: ntot ! Total number of atoms in file
    Integer (Kind=4) :: atom1, atom2 ! Atom indices from file

! Loop indices
    Integer (Kind=4) :: i, j ! General indices
    Integer (Kind=4) :: ip ! Index for Cartesian directions
    Integer (Kind=4) :: iatom1, iatom2 ! Unit cell atom indices
    Integer (Kind=4) :: ix1, iy1, iz1 ! Supercell indices for atom1
    Integer (Kind=4) :: ix2, iy2, iz2 ! Supercell indices for atom2

! Mass matrix for mass-weighting force constants
    Real (Kind=8) :: mm(natoms, natoms) ! sqrt(m_i * m_j)

    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Starting reading 2nd force constants ...                        '
    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Reading force constants from FORCE_CONSTANTS file ...'
    Write (*, '(3(a,i0))') '  Expected supercell size: ', nsize(1), ' x ', nsize(2), ' x ', nsize(3)
    Write (*, '(a,i0)') '     Expected total atoms: ', nsize(1)*nsize(2)*nsize(3)*natoms

    Do i = 1, natoms
      mm(i, i) = masses2(i)
      Do j = i + 1, natoms
        mm(i, j) = sqrt(masses2(i)*masses2(j))
        mm(j, i) = mm(i, j)
      End Do
    End Do

    Allocate (fc_short(natoms,3,nsize(1),nsize(2),nsize(3),natoms,3))

! Phonopy's 2nd-order format
    Open (1, File='FORCE_CONSTANTS', Status='old')
    Read (1, *) ntot
    Write (*, '(a,i0)') '          Number of atoms: ', ntot
    If (ntot/=nsize(1)*nsize(2)*nsize(3)*natoms) Then
      Write (*, '(a)') 'Error: wrong number of force constants.'
      Write (*, '(a,i0)') '  Expected: ', nsize(1)*nsize(2)*nsize(3)*natoms
      Write (*, '(a,i0)') '  Found: ', ntot
      Stop
    End If
    Write (*, '(a)') '  Reading force constant matrix ...'
    Do i = 1, ntot
      Do j = 1, ntot
        Read (1, *) atom1, atom2
        Call split_index(atom1, nsize(1), nsize(2), nsize(3), ix1, iy1, iz1, iatom1)
        Call split_index(atom2, nsize(1), nsize(2), nsize(3), ix2, iy2, iz2, iatom2)
        If (ix1==1 .And. iy1==1 .And. iz1==1) Then
          Do ip = 1, 3
            Read (1, *) fc_short(iatom1, ip, ix2, iy2, iz2, iatom2, :)
          End Do
        Else
          Do ip = 1, 3
            Read (1, *)
          End Do
        End If
      End Do
    End Do
    Close (1)

! Apply symmetrization if requested
    If (fc_symmetry) Then
      Call symmetrize_force_constants(10)
    End If

! Reduce force constants using atomic masses
    Write (*, '(a)') '  Weighting force constants with atomic masses ...'
    Do iatom1 = 1, natoms
      Do iatom2 = 1, natoms
        fc_short(iatom1, :, :, :, :, iatom2, :) = fc_short(iatom1, :, :, :, :, iatom2, :)/mm(iatom1, iatom2)
      End Do
    End Do
    fc_short = dm2thz*fc_short
    Write (*, '(a)') '  Force constants converted to THz^2 units'
    Write (*, *)
    Write (*, '(a)') 'Read the FORCE_CONSTANTS successfully.'
    Write (*, '(a)')
  End Subroutine read2fc

!===========================================================================
! Convert Phonopy supercell index to unit cell + atom indices
!
! Phonopy uses a linear indexing scheme for atoms in a supercell:
!   idx = ((iz-1)*ny + (iy-1))*nx + (ix-1) + (iatom-1)*nx*ny*nz + 1
!
! This subroutine reverses this mapping to extract:
!   - Unit cell indices: (ix, iy, iz)
!   - Atom index within unit cell: iatom
!
! Input:
!   idx - Linear atom index (1-based, Phonopy format)
!   nx, ny, nz - Supercell dimensions
! Output:
!   ix, iy, iz - Unit cell indices (1-based)
!   iatom - Atom index within unit cell (1-based)
!===========================================================================
  Subroutine split_index(idx, nx, ny, nz, ix, iy, iz, iatom)
    Use func, Only: divmod
    Implicit None

    Integer (Kind=4), Intent (In) :: idx, nx, ny, nz
    Integer (Kind=4), Intent (Out) :: ix, iy, iz, iatom
    Integer (Kind=4) :: tmp1, tmp2

! Extract indices using integer division
! Convert from 1-based to 0-based for calculation
    Call divmod(idx-1, nx, tmp1, ix) ! ix = (idx-1) mod nx
    Call divmod(tmp1, ny, tmp2, iy) ! iy = tmp1 mod ny
    Call divmod(tmp2, nz, iatom, iz) ! iz = tmp2 mod nz, iatom = tmp2/nz

! Convert back to 1-based indexing
    ix = ix + 1
    iy = iy + 1
    iz = iz + 1
    iatom = iatom + 1
  End Subroutine split_index
End Module readinp
