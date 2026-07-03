!=============================================================================
! Phonon band structure calculation module
!
! This module provides functionality to calculate phonon band structures
! along high-symmetry paths in the Brillouin zone.
!=============================================================================

Module band_calc
  Implicit None
  Private
  Public :: calculate_band

Contains

!===========================================================================
! Calculate phonon band structure along specified paths
!
! This subroutine:
!   1. Generates q-points along each band path
!   2. Calculates phonon frequencies using dmsolver
!   3. Converts frequencies to meV
!   4. Writes band structure data to phononband.dat
!   5. Optionally writes eigenvectors to phononbandvect.dat
!
! Input: Uses global variables from variables module
! Output: phononband.dat, phononbandvect.dat (optional)
!===========================================================================
  Subroutine calculate_band()
    Use variables, Only: natoms, nbands, band_paths, band_npoints, nband_paths, rlatvec, masses2, eigenvector, velocity
    Use spectra, Only: dmsolver
    Use output, Only: write_phononband, write_phononbandvelocity, write_phononvect
    Use constants, Only: eps3, pi, thz2mev, eps5

    Implicit None

! Loop indices and counters
    Integer (Kind=4) :: ipath ! Index for band paths
    Integer (Kind=4) :: nqtot ! Total number of q-points
    Integer (Kind=4) :: iq ! Index for q-points
    Integer (Kind=4) :: iq_global ! Global q-point index across all paths
    Integer (Kind=4) :: iband ! Index for phonon bands

! Q-point arrays
    Real (Kind=8), Allocatable :: qband(:, :) ! q-points in Cartesian coordinates (3, nqtot)
    Real (Kind=8), Allocatable :: q_directions(:, :) ! q-directions for NAC (3, nqtot)
    Real (Kind=8), Allocatable :: qfrac(:, :) ! q-points in fractional coordinates (3, nqtot)
    Real (Kind=8), Allocatable :: qdist(:) ! Cumulative distance along path (nqtot)
    Real (Kind=8) :: dq(3) ! q-point spacing along path
    Real (Kind=8) :: dir(3) ! q-point direction
    Real (Kind=8) :: dist ! Distance between consecutive q-points

! Phonon frequencies and eigenvectors
    Real (Kind=8), Allocatable :: omegas(:, :) ! Phonon frequencies (nqtot, nbands) [meV]
    Complex (Kind=8), Allocatable :: eigenvecs(:, :, :) ! Eigenvectors (nqtot, nbands, nbands)

! Group velocity
    Real (Kind=8), Allocatable :: velocities(:, :) ! Group velocities (nqtot, nbands)
    Real (Kind=8), Allocatable :: velocities_xyz(:, :, :) ! Group velocities vector (3, nqtot, nbands)

! Matrix operations
    Real (Kind=8) :: inv_rlatvec(3, 3) ! Inverse of reciprocal lattice vectors.

! Print calculation information
    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Starting phonon band structure calculation ...'
    Write (*, '(a)') '================================================================'

! Validate input parameters
    If (nband_paths<=0) Then
      Write (*, '(a)') 'Error: nband_paths must be > 0 for band calculation'
      Stop
    End If

! Set number of phonon bands (3 degrees of freedom per atom)
    nbands = 3*natoms

! Calculate total number of q-points across all paths
    nqtot = 0
    Do ipath = 1, nband_paths
      nqtot = nqtot + band_npoints(ipath)
    End Do

    Write (*, '(a,i0)') '    Number of band paths: ', nband_paths
    Write (*, '(a,i0)') 'Total number of q-points: ', nqtot
    Write (*, '(a,i0)') '  Number of phonon bands: ', nbands
    Write (*, '(a)')

! Allocate arrays for q-points, frequencies, and distances
    Allocate (qband(3,nqtot))
    Allocate (q_directions(3,nqtot))
    Allocate (omegas(nqtot,nbands))
    Allocate (qdist(nqtot))
    Allocate (qfrac(3,nqtot))

! Compute inverse of reciprocal lattice vectors for coordinate conversion
    Call compute_inverse_3x3(rlatvec, inv_rlatvec)

! Generate q-points along each band path
! Each path is defined by start and end points in fractional coordinates
    iq_global = 1
    Do ipath = 1, nband_paths
! Validate number of points (need at least 2 for interpolation)
      If (band_npoints(ipath)<2) Then
        Write (*, '(a,i0)') 'Error: band_npoints must be >= 2 for path ', ipath
        Stop
      End If

! Calculate q-point spacing along path
      qband(:, iq_global) = matmul(rlatvec, band_paths(:,1,ipath))
      qfrac(:, iq_global) = band_paths(:, 1, ipath)
      dq = (matmul(rlatvec,band_paths(:,2,ipath))-qband(:,iq_global))/real(band_npoints(ipath)-1, kind=8)

! Calculate direction vector for NAC
      If (sum(dq**2)>1.0D-20) Then
        dir = dq/sqrt(sum(dq**2))
      Else
        dir = 0.D0
      End If
      q_directions(:, iq_global) = dir

! Initialize the first point of each path segment.
      If (iq_global==1) Then
        qdist(iq_global) = 0.D0
      Else
        qdist(iq_global) = qdist(iq_global-1)
      End If
      iq_global = iq_global + 1

      Do iq = 2, band_npoints(ipath)
! Generate coordinates
        qband(:, iq_global) = qband(:, iq_global-1) + dq
        q_directions(:, iq_global) = dir
        qfrac(:, iq_global) = matmul(inv_rlatvec, qband(:,iq_global))/(2.D0*pi)

! Calculate cumulative distance along path (for plotting)
        dist = sqrt(sum((qband(:,iq_global)-qband(:,iq_global-1))**2))
        qdist(iq_global) = qdist(iq_global-1) + dist

        iq_global = iq_global + 1
      End Do
    End Do

! Allocate arrays for eigenvectors and initialize
    Allocate (eigenvecs(nqtot,nbands,nbands))
    omegas = 0.D0
    eigenvecs = 0.D0

! Solve the dynamical matrix for all q-points.
! dmsolver returns angular frequencies in THz.
    If (velocity) Then
      Write (*, '(a)') 'Calculating group velocities (analytical method) ...'
      Allocate (velocities(nqtot,nbands))
      Allocate (velocities_xyz(nqtot,nbands,3))
      velocities_xyz = 0.D0
      velocities = 0.D0
      Call dmsolver(qband, omegas, eigenvecs, q_directions, velocities_xyz)
! Calculate magnitudes
      Do iq = 1, nqtot
        Do iband = 1, nbands
          velocities(iq, iband) = sqrt(sum(velocities_xyz(iq,iband,:)**2))
        End Do
      End Do
    Else
      Call dmsolver(qband, omegas, eigenvecs, q_directions)
    End If

! Convert frequencies from angular frequency (THz) to energy (meV)
    omegas = omegas/(2.D0*pi)*thz2mev

! Write band structure to file
    Call write_phononband(nqtot, nbands, qdist, omegas)

! Calculate and write group velocities if requested
    If (velocity .And. allocated(velocities) .And. allocated(velocities_xyz)) Then
      Call write_phononbandvelocity(nqtot, nbands, qdist, omegas, velocities, velocities_xyz)
      Deallocate (velocities, velocities_xyz)
    End If

! Write eigenvectors to modes.band (if requested)
    If (eigenvector) Then
      Call write_phononvect('phononbandvect.dat', nqtot, nbands, natoms, qfrac, omegas, eigenvecs, masses2)
    End If
    Write (*, '(a)') 'Band structure calculation finished.'
    Write (*, *)

    Deallocate (qband, omegas, qdist, eigenvecs, qfrac)
  End Subroutine calculate_band

!===========================================================================
! Compute inverse of a 3x3 matrix using Cramer's rule
!
! Input:
!   A(3,3) - Input matrix
! Output:
!   Ainv(3,3) - Inverse matrix
!
! Uses an explicit closed-form formula for a 3x3 matrix inverse.
!===========================================================================
  Subroutine compute_inverse_3x3(a, ainv)
    Implicit None
    Real (Kind=8), Intent (In) :: a(3, 3) ! Input matrix
    Real (Kind=8), Intent (Out) :: ainv(3, 3) ! Inverse matrix
    Real (Kind=8) :: det ! Determinant of A

! Calculate determinant using explicit formula
    det = a(1, 1)*(a(2,2)*a(3,3)-a(2,3)*a(3,2)) &
        - a(1, 2)*(a(2,1)*a(3,3)-a(2,3)*a(3,1)) &
        + a(1, 3)*(a(2,1)*a(3,2)-a(2,2)*a(3,1))

! Check for singular matrix (determinant close to zero)
    If (abs(det)<1.D-10) Then
      Write (*, '(a)') 'Error: singular matrix in compute_inverse_3x3'
      Stop
    End If

    ainv(1, 1) = (a(2,2)*a(3,3)-a(2,3)*a(3,2))/det
    ainv(1, 2) = (a(1,3)*a(3,2)-a(1,2)*a(3,3))/det
    ainv(1, 3) = (a(1,2)*a(2,3)-a(1,3)*a(2,2))/det
    ainv(2, 1) = (a(2,3)*a(3,1)-a(2,1)*a(3,3))/det
    ainv(2, 2) = (a(1,1)*a(3,3)-a(1,3)*a(3,1))/det
    ainv(2, 3) = (a(1,3)*a(2,1)-a(1,1)*a(2,3))/det
    ainv(3, 1) = (a(2,1)*a(3,2)-a(2,2)*a(3,1))/det
    ainv(3, 2) = (a(1,2)*a(3,1)-a(1,1)*a(3,2))/det
    ainv(3, 3) = (a(1,1)*a(2,2)-a(1,2)*a(2,1))/det

  End Subroutine compute_inverse_3x3
End Module band_calc
