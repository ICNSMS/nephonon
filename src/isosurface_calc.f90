!=============================================================================
! Phonon isosurface calculation module
!
! This module calculates phonon isosurfaces and outputs data in FermiSurfer
! format for visualization. The isosurface represents constant phonon
! frequency surfaces in the Brillouin zone.
!
! Output format: FermiSurfer (.fs) format
!=============================================================================

Module isosurface_calc
  Implicit None
  Private
  Public :: calculate_isosurface

Contains

!===========================================================================
! Calculate phonon isosurface and output in FermiSurfer format
!
! This subroutine:
!   1. Generates Monkhorst-Pack q-point mesh
!   2. Calculates phonon frequencies using dmsolver
!   3. Writes data in FermiSurfer format for visualization
!
! Input: Uses global variables from variables module
! Output: phononsurface.fs (FermiSurfer format)
!===========================================================================
  Subroutine calculate_isosurface()

    Use variables, Only: natoms, nbands, isosurface_qmesh, rlatvec
    Use spectra, Only: dmsolver
    Use output, Only: write_phononsurface
    Use constants, Only: eps3, pi, thz2mev

    Implicit None

! Loop indices
    Integer (Kind=4) :: nqtot ! Total number of q-points
    Integer (Kind=4) :: ll    ! Linear index for q-points
    Integer (Kind=4) :: ik1, ik2, ik3 ! Indices for Monkhorst-Pack grid

! Q-point arrays
    Real (Kind=8), Allocatable :: qiso(:, :)  ! q-points in Cartesian coordinates (3, nqtot)
    Real (Kind=8), Allocatable :: qfrac(:, :) ! q-points in fractional coordinates (3, nqtot)
    Integer (Kind=4), Allocatable :: q_index(:, :, :) ! Mapping from (ik1,ik2,ik3) to linear index iq

! Phonon frequencies and eigenvectors
    Real (Kind=8), Allocatable :: omegas(:, :) ! Phonon frequencies (nqtot, nbands) [meV]
    Complex (Kind=8), Allocatable :: eigenvecs(:, :, :) ! Eigenvectors (nqtot, nbands, nbands)

    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Starting isosurface calculation ...'
    Write (*, '(a)') '================================================================'
    Write (*, '(3(a,i0))') '                  q-mesh: ', isosurface_qmesh(1), ' x ', isosurface_qmesh(2), ' x ', isosurface_qmesh(3)

! Check if q-mesh is properly set
    If (any(isosurface_qmesh<1)) Then
      Write (*, '(a)') 'Error: isosurface_qmesh must be set in ISOSURFACE section.'
      Stop
    End If

! Generate q-point mesh for isosurface (Monkhorst-Pack grid)
    nqtot = isosurface_qmesh(1)*isosurface_qmesh(2)*isosurface_qmesh(3)
    Write (*, '(a,i0)') 'Total number of q-points: ', nqtot
    Write (*, '(a,i0)') '  Number of phonon bands: ', nbands
    Write (*, '(a)')
    Allocate (qiso(3,nqtot))
    Allocate (qfrac(3,nqtot))
    Allocate (q_index(isosurface_qmesh(1),isosurface_qmesh(2),isosurface_qmesh(3)))

! Generate Monkhorst-Pack q-point mesh
! Monkhorst-Pack grid provides better k-point sampling than uniform grid
! Formula: x_i = (2*i - 1 - N_i) / (2*N_i), where i = 1, 2, ..., N_i
! This gives q-points in the range [-0.5, 0.5] in fractional coordinates
    ll = 0
    Do ik1 = 1, isosurface_qmesh(1)
      Do ik2 = 1, isosurface_qmesh(2)
        Do ik3 = 1, isosurface_qmesh(3)
          ll = ll + 1
! Calculate fractional coordinates using Monkhorst-Pack formula
          qfrac(1, ll) = (2.D0*ik1-1.D0-isosurface_qmesh(1))/(2.D0*isosurface_qmesh(1))
          qfrac(2, ll) = (2.D0*ik2-1.D0-isosurface_qmesh(2))/(2.D0*isosurface_qmesh(2))
          qfrac(3, ll) = (2.D0*ik3-1.D0-isosurface_qmesh(3))/(2.D0*isosurface_qmesh(3))
! Convert to Cartesian coordinates
          qiso(:, ll) = rlatvec(:,1)*qfrac(1,ll) &
                      + rlatvec(:,2)*qfrac(2,ll) &
                      + rlatvec(:,3)*qfrac(3,ll)
! Store mapping from grid indices to linear index
          q_index(ik1, ik2, ik3) = ll
        End Do
      End Do
    End Do

! Calculate phonon frequencies
    nbands = 3*natoms
    Allocate (omegas(nqtot,nbands))
    Allocate (eigenvecs(nqtot,nbands,nbands))

    omegas = 0.D0
    eigenvecs = 0.D0

    Call dmsolver(qiso, omegas, eigenvecs)

! Convert to meV
    omegas = omegas/(2.D0*pi)*thz2mev

! Set negative frequencies to zero
    Where (omegas<0.D0) omegas = 0.D0
    Where (omegas<eps3) omegas = omegas + eps3

! Write isosurface data in FermiSurfer format
    Call write_phononsurface(isosurface_qmesh, nbands, rlatvec, omegas, q_index)

    Write (*, '(a)') 'Phonon Isosurface calculation finished.'
    Write (*, *)

    Deallocate (qiso, qfrac, omegas, eigenvecs, q_index)
  End Subroutine calculate_isosurface
End Module isosurface_calc
