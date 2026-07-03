!=============================================================================
! Main program for phonon calculations
! 
! This program calculates phonon properties including:
!   - Second-order force constant calculation
!   - Phonon density of states calculation
!   - Phonon band structure calculation
!   - Phonon isosurface calculation (FermiSurfer format)
!   - Neutron scattering calculation (S(Q,E))
!   - LO-TO splitting support (non-analytic correction)
!   - Eigenvector output
!   - Phonon group velocities output
!
! Software: nephonon
! Version: 1.0
!=============================================================================

Program nephonon
  Use readinp, Only: input_parser, read2fc, readborn
  Use variables, Only: dos, band, isosurface, sqw_crystal, sqw_powder, gen2ndfc, nonanalytic
  Use dos_calc, Only: calculate_dos
  Use band_calc, Only: calculate_band
  Use isosurface_calc, Only: calculate_isosurface
  Use sqw_phonon, Only: run_sqw_crystal, run_sqw_powder
  Use calc_fc2_mod, Only: run_calc_fc2
  Implicit None

! Variables for timing the program execution
  Integer (Kind=4) :: time_begin, time_end, time_rate
  Real (Kind=8) :: time_last
  Character (Len=100) :: arg ! Command line argument
  Integer (Kind=4) :: nargs ! Number of command line arguments

! Check for help request from command line
  nargs = command_argument_count()
  If (nargs>0) Then
    Call get_command_argument(1, arg)
    If (arg=='-h' .Or. arg=='--help' .Or. arg=='help') Then
      Call print_help()
      Stop
    End If
  End If

! Start timing and print program header
  Call system_clock(time_begin, time_rate)
  Call print_header()

! Step 1: Read input file and parse crystal structure
  Call input_parser()

! Step 1.5: Calculate Force Constants if requested
  If (gen2ndfc) Then
    Call run_calc_fc2()
  End If

! Step 2: Read FORCE_CONSTANTS and weight them with atomic masses
  If (dos .Or. band .Or. isosurface .Or. sqw_crystal .Or. sqw_powder) Then
    Call read2fc()
    If (nonanalytic) Then
      Call readborn()
    End If
  End If

! Step 3: Calculate phonon DOS if requested
  If (dos) Then
    Call calculate_dos()
  End If

! Step 4: Calculate phonon band structure if requested
  If (band) Then
    Call calculate_band()
  End If

! Step 5: Calculate phonon isosurface if requested
  If (isosurface) Then
    Call calculate_isosurface()
  End If

! Step 6: Calculate crystal neutron scattering if requested
  If (sqw_crystal) Then
    Call run_sqw_crystal()
  End If

! Step 7: Calculate powder neutron scattering if requested
  If (sqw_powder) Then
    Call run_sqw_powder()
  End If

! Calculate and display total execution time
  Call system_clock(time_end)
  If (time_rate>0) Then
    time_last = real(time_end-time_begin, kind=8)/real(time_rate, kind=8)
  Else
    time_last = 0.D0
  End If

  Write (*, '(a,f0.2,a)') 'The program lasts ', time_last, ' seconds.'
  Write (*, *)
  Write (*, '(a)') '================================================================'
  Write (*, '(a)') '     NEPHONON: A Fast Phonon Calculator                         '
  Write (*, '(a)') '         Version 1.0 (Fortran Rewrite)                          '
  Write (*, '(a)') '================================================================'
Contains

!===========================================================================
! Print program header with version and feature information
!===========================================================================
  Subroutine print_header()
    Implicit None
    Write (*, '(a)') '================================================================'
    Write (*, '(a)') '     NEPHONON: A Fast Phonon Calculator                         '
    Write (*, '(a)') '         Version 1.0 (Fortran Rewrite)                          '
    Write (*, '(a)') '================================================================'
    Write (*, '(a)')
    Write (*, '(a)') 'Features:'
    Write (*, '(a)') '  - Second-order force constant calculation'
    Write (*, '(a)') '  - Phonon density of states calculation'
    Write (*, '(a)') '  - Phonon band structure calculation'
    Write (*, '(a)') '  - Phonon isosurface calculation (FermiSurfer format)'
    Write (*, '(a)') '  - Neutron scattering calculation (S(Q,E))'
    Write (*, '(a)') '  - LO-TO splitting support (non-analytic correction)'
    Write (*, '(a)') '  - Eigenvector output'
    Write (*, '(a)') '  - Phonon group velocities output'
    Write (*, '(a)')
    Write (*, '(a)')
  End Subroutine print_header

!===========================================================================
! Print detailed help information including:
!   - Usage instructions
!   - Input file format
!   - Output file descriptions
!===========================================================================
  Subroutine print_help()
    Implicit None
    Write (*, '(a)') '================================================================'
    Write (*, '(a)') '     Calculation Program - Help                                 '
    Write (*, '(a)') '================================================================'
    Write (*, '(a)')
    Write (*, '(a)') 'Usage:'
    Write (*, '(a)') '  nephonon'
    Write (*, '(a)') '  nephonon -h | --help | help'
    Write (*, '(a)')
    Write (*, '(a)') 'Description:'
    Write (*, '(a)') '  nephonon is a high-performance tool for calculating phonon'
    Write (*, '(a)') '  properties including Density of States (DOS), Band Structure,'
    Write (*, '(a)') '  isosurface, and Neutron Scattering intensities (S(Q,E)). '
    Write (*, '(a)') '  It supports NEP-based second-order force constant calculation.'
    Write (*, '(a)') '     '
    Write (*, '(a)') 'Arguments:'
    Write (*, '(a)') '  -h, --help    Display this help message'
    Write (*, '(a)')
    Write (*, '(a)') 'Input Files:'
    Write (*, '(a)') '  1. inp.control          Main input file controlling execution'
    Write (*, '(a)') '  2. FORCE_CONSTANTS      Force constants file (Phonopy format)'
    Write (*, '(a)') '  3. inp.lotosplitting    LO-TO splitting data (optional)'
    Write (*, '(a)') '  4. nep.txt              Neuroevolution potential (optional)'
    Write (*, '(a)')
    Write (*, '(a)') 'Input File Format (inp.control):'
    Write (*, '(a)')
    Write (*, '(a)') '  &basic'
    Write (*, '(a)') '       ntypes = 2            ! Number of atom types'
    Write (*, '(a)') '       natoms = 4            ! Total number of atoms'
    Write (*, '(a)') '        nsize = 3, 3, 3      ! Supercell size'
    Write (*, '(a)') '  /'
    Write (*, '(a)')
    Write (*, '(a)') '  &inputph'
    Write (*, '(a)') '     elements = ''Si'', ''O''    ! Element names'
    Write (*, '(a)') '          nat = 2, 2         ! Number of each element'
    Write (*, '(a)') '     gen2ndfc = .false.      ! Generate Force Constants'
    Write (*, '(a)') '          dos = .false.      ! Calculate DOS'
    Write (*, '(a)') '         band = .false.      ! Calculate band structure'
    Write (*, '(a)') '     velocity = .false.      ! Output group velocity'
    Write (*, '(a)') '  eigenvector = .false.      ! Output eigenvectors'
    Write (*, '(a)') '  fc_symmetry = .false.      ! Symmetrize force constants'
    Write (*, '(a)') '  nonanalytic = .false.      ! Enable LO-TO splitting'
    Write (*, '(a)') '   isosurface = .false.      ! Calculate isosurface'
    Write (*, '(a)') '  sqw_crystal = .false.      ! Calculate Single Crystal S(Q,E)'
    Write (*, '(a)') '   sqw_powder = .false.      ! Calculate Powder S(|Q|,E)'
    Write (*, '(a)') '  /'
    Write (*, '(a)')
    Write (*, '(a)') '  &inputsqw'
    Write (*, '(a)') '        e_min = 0.0          ! Energy start (meV)'
    Write (*, '(a)') '        e_max = 10.0         ! Energy end (meV)'
    Write (*, '(a)') '      ne_bins = 1000         ! Number of energy bins'
    Write (*, '(a)') '   e_smearing = 1.17741 0.0 0.0 0.0 0.0  ! FWHM broadening polynomial (meV)'
    Write (*, '(a)') '  temperature = 300          ! Temperature in Kelvin'
    Write (*, '(a)') '     dw_qmesh = 10 10 10     ! Q-mesh for Debye-Waller factor calculation'
    Write (*, '(a)') '       lphase = .false.      ! '
    Write (*, '(a)') '        q_min = 0.0          ! Range for powder calculation'
    Write (*, '(a)') '        q_max = 4.0'
    Write (*, '(a)') '      nq_bins = 400          ! Number of samples at each |q| sphere'
    Write (*, '(a)') '     sampling = ''golden''   ! Method for sampling'
    Write (*, '(a)') '  npts_sphere = 100'
    Write (*, '(a)') '  /'
    Write (*, '(a)')
    Write (*, '(a)') '  Displace_DELTA'
    Write (*, '(a)') '  0.01                       ! Displacement distance for finite difference'
    Write (*, '(a)')
    Write (*, '(a)') '  DOS_SIGMA'
    Write (*, '(a)') '  0.2                        ! Gauss smearing'
    Write (*, '(a)')
    Write (*, '(a)') '  LATTICE_PARAMETERS'
    Write (*, '(a)') '  5.431 0.000 0.000          ! Lattice vector 1'
    Write (*, '(a)') '  0.000 5.431 0.000          ! Lattice vector 2'
    Write (*, '(a)') '  0.000 0.000 5.431          ! Lattice vector 3'
    Write (*, '(a)')
    Write (*, '(a)') '  ATOMIC_POSITIONS'
    Write (*, '(a)') '  Direct                     ! Coordinate type (Direct/Cartesian)'
    Write (*, '(a)') '  0.000 0.000 0.000          ! Atom 1 position'
    Write (*, '(a)') '  0.250 0.250 0.250          ! Atom 2 position'
    Write (*, '(a)') '  ...                        ! More atoms'
    Write (*, '(a)')
    Write (*, '(a)') '  DENSITY_OF_STATES          ! Required if dos = .true.'
    Write (*, '(a)') '  20 20 20                   ! q-mesh for DOS'
    Write (*, '(a)')
    Write (*, '(a)') '  BANDS_STRUCTURE            ! Required if band = .true.'
    Write (*, '(a)') '  3                          ! Number of paths'
    Write (*, '(a)') '  0.0 0.0 0.0 0.5 0.0 0.0 50 ! Path 1: start, end, npoints'
    Write (*, '(a)') '  0.5 0.0 0.0 0.5 0.5 0.0 50 ! Path 2'
    Write (*, '(a)') '  0.5 0.5 0.0 0.0 0.0 0.0 50 ! Path 3'
    Write (*, '(a)')
    Write (*, '(a)') '  ISOSURFACE                 ! Required if isosurface = .true.'
    Write (*, '(a)') '  30 30 30                   ! q-mesh for isosurface'
    Write (*, '(a)')
    Write (*, '(a)') 'Output Files:'
    Write (*, '(a)') '  - phonondos.dat            DOS data (if dos = .true.)'
    Write (*, '(a)') '  - phonondosvect.dat        DOS eigenvectors (if eigenvectors = .true.)'
    Write (*, '(a)') '  - phonondosvelocity.dat    DOS group velocity (if velocity = .true.)'
    Write (*, '(a)') '  - phononband.dat           Band structure data (if band = .true.)'
    Write (*, '(a)') '  - phononbandvect.dat       Band eigenvectors (if eigenvectors = .true.)'
    Write (*, '(a)') '  - phononbandvelocity.dat   Band group velocity (if velocity = .true.)'
    Write (*, '(a)') '  - phononsurface.fs         Isosurface data in FermiSurfer format'
    Write (*, '(a)') '  - sqw_crystal.dat          Single crystal S(Q,E) data'
    Write (*, '(a)') '  - sqw_powder.dat           Powder S(|Q|,E) data'
    Write (*, '(a)')
    Write (*, '(a)') 'For more information, see the documentation or source code.'
    Write (*, '(a)')
  End Subroutine print_help
End Program nephonon