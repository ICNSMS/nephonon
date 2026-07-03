!=============================================================================
! Phonon Density of States (DOS) calculation module
!
! This module calculates the phonon density of states by:
!   1. Generating a uniform q-point mesh in the Brillouin zone
!   2. Calculating phonon frequencies at each q-point
!   3. Using Gaussian smearing to compute DOS
!   4. Normalizing the DOS
!=============================================================================

Module dos_calc
  Implicit None
  Private
  Public :: calculate_dos

Contains

!===========================================================================
! Calculate phonon Density of States (DOS)
!
! This subroutine:
!   1. Generates a uniform q-point mesh
!   2. Calculates phonon frequencies using dmsolver
!   3. Computes DOS using Gaussian smearing method
!   4. Writes DOS data to phonondos.dat
!   5. Optionally writes eigenvectors to phonondosvect.dat
!
! Input: Uses global variables from variables module
! Output: phonondos.dat, phonondosvect.dat (optional)
!===========================================================================
  Subroutine calculate_dos()
    Use variables, Only: natoms, nbands, dos_qmesh, dos_omega, dos_value, dos_sigma, &
                         rlatvec, masses2, eigenvector, velocity
    Use spectra, Only: dmsolver
    Use output, Only: write_phonondos, write_phonondosvelocity, write_phononvect
    Use constants, Only: eps3, pi, thz2mev

    Implicit None

! Loop indices
    Integer (Kind=4) :: nqtot ! Total number of q-points in mesh
    Integer (Kind=4) :: ii, jj, kk ! Indices for q-mesh generation
    Integer (Kind=4) :: ll ! Linear index for q-points
    Integer (Kind=4) :: iq ! Index for q-points
    Integer (Kind=4) :: nomega ! Number of frequency grid points
    Integer (Kind=4) :: iomega ! Index for frequency grid

! Frequency range and grid
    Real (Kind=8) :: omega_max ! Maximum phonon frequency [meV]
    Real (Kind=8) :: omega_min ! Minimum phonon frequency [meV]
    Real (Kind=8) :: domega ! Frequency grid spacing (meV).
    Real (Kind=8), Allocatable :: omega_grid(:)

! Velocity calculation variables
    Real (Kind=8), Allocatable :: velocities_xyz(:, :, :) ! Group velocities vector (nqtot, nbands, 3)

! Q-point arrays
    Real (Kind=8), Allocatable :: qdos(:, :) ! q-points in Cartesian coordinates (3, nqtot)
    Real (Kind=8), Allocatable :: qfrac(:, :) ! q-points in fractional coordinates (3, nqtot)

! Phonon frequencies and eigenvectors
    Real (Kind=8), Allocatable :: omegas(:, :) ! Phonon frequencies (nqtot, nbands) [meV]
    Complex (Kind=8), Allocatable :: eigenvecs(:, :, :) ! Eigenvectors (nqtot, nbands, nbands)

! Gaussian smearing widths
    Integer (Kind=4) :: nwidths ! Number of different widths
    Integer (Kind=4) :: iwidth ! Index for width
    Real (Kind=8) :: width ! Current Gaussian width [meV]
    Real (Kind=8), Allocatable :: widths(:) ! Array of Gaussian widths [meV]
    Real (Kind=8), Allocatable :: dos_values(:, :) ! DOS values for each width (nomega, nwidths)

    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Starting density of states calculation ...'
    Write (*, '(a)') '================================================================'
    Write (*, '(3(a,i0))') '                  q-mesh: ', dos_qmesh(1), ' x ', dos_qmesh(2), ' x ', dos_qmesh(3)
    Write (*, '(a,i0)') 'Total number of q-points: ', dos_qmesh(1)*dos_qmesh(2)*dos_qmesh(3)
    Write (*, '(a,i0)') '  Number of phonon bands: ', 3*natoms
    Write (*, '(a,f0.2,a,f0.2)') '          Smearing width: ', dos_sigma, ' ~ ', dos_sigma*10.D0
    Write (*, '(a)')

! Generate uniform q-point mesh in the Brillouin zone
! The mesh is a regular grid in fractional coordinates
    nqtot = dos_qmesh(1)*dos_qmesh(2)*dos_qmesh(3)
    Allocate (qdos(3,nqtot))
    Allocate (qfrac(3,nqtot))

! Generate q-points on a uniform grid
! qfrac ranges from 0 to 1 in each direction.
    ll = 0
    Do ii = 1, dos_qmesh(1)
      Do jj = 1, dos_qmesh(2)
        Do kk = 1, dos_qmesh(3)
          ll = ll + 1
! Fractional coordinates (0 to 1)
          qfrac(1, ll) = (ii-1.D0)/dos_qmesh(1)
          qfrac(2, ll) = (jj-1.D0)/dos_qmesh(2)
          qfrac(3, ll) = (kk-1.D0)/dos_qmesh(3)
! Convert to Cartesian coordinates using reciprocal lattice vectors
          qdos(:, ll) = rlatvec(:,1)*qfrac(1,ll) &
                      + rlatvec(:,2)*qfrac(2,ll) &
                      + rlatvec(:,3)*qfrac(3,ll)
        End Do
      End Do
    End Do

! Calculate phonon frequencies
    nbands = 3*natoms
    Allocate (omegas(nqtot,nbands))
    Allocate (eigenvecs(nqtot,nbands,nbands))
    omegas = 0.D0
    eigenvecs = 0.D0

    If (velocity) Then
      Write (*, '(a)') 'Calculating group velocities (analytical method) ...'
      Allocate (velocities_xyz(nqtot,nbands,3))
      Call dmsolver(qdos, omegas, eigenvecs, velocities=velocities_xyz)
    Else
      Call dmsolver(qdos, omegas, eigenvecs)
    End If

! Convert to meV
    omegas = omegas/(2.D0*pi)*thz2mev

! Set negative frequencies to zero
    Where (omegas<0.D0) omegas = 0.D0
    Where (omegas<eps3) omegas = omegas + eps3

! Find frequency range
    omega_min = minval(omegas)
    omega_max = maxval(omegas)
    Write (*, '(a,2(f0.2,a))') 'Frequency range: [ ', omega_min, ' ~ ', omega_max, ' ] meV'

! Create frequency grid (1000 points)
    nomega = 1000

!write(*,*) "Using", nomega, "points for DOS grid"
    Write (*, *)
    domega = (omega_max-omega_min)/(nomega-1)
    Allocate (omega_grid(nomega))
    Do iomega = 1, nomega
      omega_grid(iomega) = omega_min + (iomega-1)*domega
    End Do

! Calculate group velocities if requested
    If (velocity) Then
      Call write_phonondosvelocity(nqtot, nbands, omegas, velocities_xyz)
      Deallocate (velocities_xyz)
    End If

! Calculate DOS using Gaussian smearing method
! Each phonon mode contributes a Gaussian peak centered at its frequency
! Define Gaussian widths.
    nwidths = 10
    Allocate (widths(nwidths))
    widths = (/ 1.0D0, 2.0D0, 3.0D0, 4.0D0, 5.0D0, 6.0D0, 7.0D0, 8.0D0, 9.0D0, 10.0D0 /)
    widths = dos_sigma*widths

! Allocate DOS array for all widths
    Allocate (dos_values(nomega,nwidths))
    dos_values = 0.D0

! Calculate DOS for each width
    Do iwidth = 1, nwidths
      width = widths(iwidth)
!write(*,'(a,f10.2,a)') "Calculating DOS with Gaussian width =", width, " meV"

! Calculate DOS using Gaussian smearing
      Do iq = 1, nqtot
        Do ii = 1, nbands
! Only include modes with non-zero frequency
          If (omegas(iq,ii)>eps3) Then
! Add Gaussian contribution to DOS at each frequency grid point
            Do iomega = 1, nomega
              dos_values(iomega, iwidth) = dos_values(iomega, iwidth) + &
                  exp(-((omega_grid(iomega) - omegas(iq, ii)) / width)**2)
            End Do
          End If
        End Do
      End Do

! Normalize DOS
! The normalization factor accounts for:
!   - Number of q-points (nqtot)
!   - Gaussian normalization (sqrt(pi) * width)
!   - This ensures DOS integrates to the total number of modes
      dos_values(:, iwidth) = dos_values(:, iwidth)/(nqtot*sqrt(pi)*width)
    End Do

! Store frequency array
    Allocate (dos_omega(nomega))
    dos_omega = omega_grid

! Store first width DOS in dos_value for backward compatibility
    Allocate (dos_value(nomega))
    dos_value = dos_values(:, 1)

! Write DOS to file with all widths
    Call write_phonondos(nomega, nwidths, dos_omega, dos_values)

! Write eigenvectors to modes.dos (if requested)
    If (eigenvector) Then
      Call write_phononvect('phonondosvect.dat', nqtot, nbands, natoms, qfrac, omegas, eigenvecs, masses2)
    End If
    Write (*, '(a)') 'DOS calculation finished.'
    Write (*, *)

    Deallocate (qdos, qfrac, omegas, eigenvecs, omega_grid, widths, dos_values)

  End Subroutine calculate_dos
End Module dos_calc
