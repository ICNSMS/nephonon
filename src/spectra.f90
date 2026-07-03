!=============================================================================
! Dynamical matrix solver module
!
! This module contains the core phonon calculation routine that:
!   1. Builds the dynamical matrix for each q-point
!   2. Includes non-analytic corrections for LO-TO splitting (optional)
!   3. Diagonalizes the dynamical matrix to obtain phonon frequencies
!   4. Returns frequencies and optionally eigenvectors
!   5. Optionally computes analytical group velocities
!=============================================================================

Module spectra
  Implicit None
  Private
  Public :: dmsolver
Contains

!===========================================================================
! Solve the dynamical matrix for phonon frequencies and eigenvectors
!
! This is the core subroutine that calculates phonon properties:
!   1. Builds dynamical matrix from force constants
!   2. Applies non-analytic correction for LO-TO splitting (if enabled)
!   3. Diagonalizes dynamical matrix using LAPACK
!   4. Returns frequencies (in THz, angular frequency) and eigenvectors
!   5. Optionally computes group velocities via analytical derivatives
!
! Inputs:
!   qspace(3, nqpt)                  - Q-points in Cartesian coordinates [1/Angstrom]
!   q_directions(3, nqpt), optional  - Direction vectors for NAC near Gamma
!   verbose, optional                - Enable progress output
! Outputs:
!   omegas(nqpt, nbands)             - Angular frequencies [THz]
!   eigenvecs(nqpt, nbands, nbands)  - Eigenvectors (optional)
!   velocities(nqpt, nbands, 3)      - Group velocities (optional)
!===========================================================================
  Subroutine dmsolver(qspace, omegas, eigenvecs, q_directions, velocities, verbose)

    Use constants, Only: thz2amua3, eps5, iunit
    Use func, Only: phexp
    Use variables, Only: natoms, nbands, nsize, masses2, vol, &
                         latvec, positions, rlatvec, &
                         fc_short, nonanalytic, epsilon, born

    Implicit None

    Real (Kind=8), Intent (In) :: qspace(:, :)
    Real (Kind=8), Intent (In), Optional :: q_directions(:, :)
    Real (Kind=8), Intent (Out) :: omegas(:, :)
    Real (Kind=8), Intent (Out), Optional :: velocities(:, :, :)
    Complex (Kind=8), Intent (Out), Optional :: eigenvecs(:, :, :)
    Logical, Intent (In), Optional :: verbose

! Number of q-points
    Integer (Kind=4) :: nqpt
    Logical :: verb

! Mass matrix (sqrt(m_i * m_j) for mass-weighting)
    Real (Kind=8), Allocatable :: mm(:, :)

! Dynamical matrices
    Complex (Kind=8), Allocatable :: dyn_total(:, :) ! Total dynamical matrix
    Complex (Kind=8), Allocatable :: dyn_nac(:, :) ! Non-analytic correction matrix
    Complex (Kind=8), Allocatable :: ddyn_total(:, :, :) ! Derivative of dynamical matrix
    Complex (Kind=8), Allocatable :: ddyn_nac(:, :, :) ! Derivative of NAC matrix

! Force constants
    Real (Kind=8), Allocatable :: fc_diel(:, :, :, :, :, :, :) ! Dielectric (long-range) force constants
    Real (Kind=8), Allocatable :: fc_total(:, :, :, :, :, :, :) ! Total force constants (short + long-range)

! Loop indices
    Integer (Kind=4) :: i, j ! Indices for Cartesian directions
    Integer (Kind=4) :: iq ! Index for q-points
    Integer (Kind=4) :: ip ! Index for equal-distance points
    Integer (Kind=4) :: neq ! Number of equal-distance points
    Integer (Kind=4) :: iatom1, iatom2 ! Indices for atoms
    Integer (Kind=4) :: ix1, iy1, iz1 ! Supercell indices for atom1
    Integer (Kind=4) :: ix2, iy2, iz2 ! Supercell indices for periodic images

! Temporary variables
    Real (Kind=8) :: tmp1, tmp2, tmp3 ! Temporary scalars
    Real (Kind=8) :: dmin ! Minimum distance
    Real (Kind=8) :: rnorm ! Distance norm
    Real (Kind=8) :: rcell(3) ! Cell vector
    Real (Kind=8) :: r(3) ! Relative position vector
    Real (Kind=8) :: rl(3) ! Lattice translation vector
    Real (Kind=8), Allocatable :: qr(:) ! q·R products for equal-distance points
    Real (Kind=8), Allocatable :: rr(:, :) ! Relative vectors for equal-distance points
    Complex (Kind=8) :: ztmp ! Temporary complex number
    Complex (Kind=8) :: star ! Sum of phase factors
    Real (Kind=8) :: q_nac(3) ! q-vector for NAC

! q-point folding to first Brillouin zone
    Real (Kind=8), Allocatable :: shortest(:, :) ! Shortest q-vector in 1st BZ (3, nqpt)

! LAPACK diagonalization arrays
    Real (Kind=8), Allocatable :: omega2(:) ! Eigenvalues (squared frequencies)
    Real (Kind=8), Allocatable :: rwork(:) ! Real work array for LAPACK
    Complex (Kind=8), Allocatable :: work(:) ! Complex work array for LAPACK
    Integer (Kind=4) :: nwork = 1 ! Size of work array (will be adjusted)

! External BLAS function for vector norm
    Real (Kind=8), External :: dnrm2

! Interface for LAPACK zheev routine
    Interface
      Subroutine zheev(jobz, uplo, n, a, lda, w, work, lwork, rwork, info)
        Import
        Character (Len=1), Intent (In) :: jobz, uplo
        Integer, Intent (In) :: n, lda, lwork
        Complex (Kind=8), Intent (Inout) :: a(lda, *)
        Real (Kind=8), Intent (Out) :: w(*)
        Complex (Kind=8), Intent (Out) :: work(*)
        Real (Kind=8), Intent (Out) :: rwork(*)
        Integer, Intent (Out) :: info
      End Subroutine zheev
    End Interface

    nqpt = size(qspace, 2)

! Check verbose flag
    If (present(verbose)) Then
      verb = verbose
    Else
      verb = .True.
    End If

    Allocate (mm(natoms,natoms))
    Allocate (omega2(nbands))
    Allocate (rwork(max(1,9*natoms-2)))

    Allocate (fc_diel(natoms,3,nsize(1),nsize(2),nsize(3),natoms,3))
    Allocate (fc_total(natoms,3,nsize(1),nsize(2),nsize(3),natoms,3))

    Do i = 1, natoms
      mm(i, i) = masses2(i)
      Do j = i + 1, natoms
        mm(i, j) = sqrt(masses2(i)*masses2(j))
        mm(j, i) = mm(i, j)
      End Do
    End Do

    Allocate (dyn_total(nbands,nbands))
    Allocate (dyn_nac(nbands,nbands))
    If (present(velocities)) Then
      Allocate (ddyn_total(nbands,nbands,3))
      Allocate (ddyn_nac(nbands,nbands,3))
      Allocate (rr(3,125))
    Else
      Allocate (ddyn_total(0,0,0))
      Allocate (ddyn_nac(0,0,0))
      Allocate (rr(0,0))
    End If
    Allocate (work(nwork))
    Allocate (shortest(3,nqpt))

! Maximum possible equal-distance points: 5×5×5 = 125
    Allocate (qr(125))

! Fold q-points to first Brillouin zone for non-analytic correction
! This improves the behavior of LO-TO splitting by using the shortest
! q-vector in the first Brillouin zone
! The non-analytic correction is only valid near Gamma point
    Do iq = 1, nqpt
      shortest(:, iq) = qspace(:, iq)
      tmp1 = dnrm2(3, shortest(:,iq), 1) ! Current distance from origin
! Search over nearby reciprocal lattice vectors to find shortest q
      Do ix1 = -2, 2
        Do iy1 = -2, 2
          Do iz1 = -2, 2
! Add reciprocal lattice vector to fold q to 1st BZ
            r = qspace(:, iq) + ix1*rlatvec(:, 1) + iy1*rlatvec(:, 2) + iz1*rlatvec(:, 3)
            tmp2 = dnrm2(3, r, 1)
! Keep the shortest vector
            If (tmp2<tmp1) Then
              tmp1 = tmp2
              shortest(:, iq) = r
            End If
          End Do
        End Do
      End Do
    End Do

! Progress output for large calculations
    If (nqpt>100 .And. verb) Then
      Write (*, '(a,i0,a)') 'Solving dynamical matrix for ', nqpt, ' q-points ...'
    End If

    Do iq = 1, nqpt
! Progress output every 10%
      If (nqpt>100 .And. mod(iq,max(1,nqpt/10))==0 .And. verb) Then
        Write (*, '(a,i3,a)') '  Progress: ', nint(real(iq)/real(nqpt)*100.D0), '%'
      End If

      dyn_total = 0.D0
      dyn_nac = 0.D0
      fc_diel = 0.D0
      If (present(velocities)) Then
        ddyn_total = 0.D0
        ddyn_nac = 0.D0
      End If

! Determine q-vector for NAC
      q_nac = shortest(:, iq)

! Handle Gamma point direction if q_directions is provided
! Use 1.0d-8 tolerance for zero check
      If (all(abs(q_nac)<1.0D-8) .And. present(q_directions)) Then
        q_nac = q_directions(:, iq)
      End If

! Apply non-analytic correction for LO-TO splitting (if enabled)
! This correction accounts for long-range electrostatic interactions
! in polar materials, which cause splitting between LO and TO modes
! at the Gamma point
! No correction is applied exactly at Gamma to avoid directional ambiguity
      If (nonanalytic .And. (.Not. all(abs(q_nac)<1.0D-8))) Then
! Calculate q·epsilon·q (dielectric screening)
        tmp3 = dot_product(q_nac, matmul(epsilon,q_nac))

! Build non-analytic correction matrix in q-space
! Formula: D_NAC = (Z*q)(Z*q) / (q·epsilon·q) / V / sqrt(m_i*m_j)
        Do iatom1 = 1, natoms
          Do iatom2 = 1, natoms
            Do i = 1, 3
              Do j = 1, 3
! Born charge times q-vector
                tmp1 = dot_product(q_nac, born(:,i,iatom1))
                tmp2 = dot_product(q_nac, born(:,j,iatom2))
! Non-analytic correction (mass-weighted)
                dyn_nac(3*(iatom1-1)+i,3*(iatom2-1)+j) = tmp1*tmp2/&
                    mm(iatom1,iatom2)
                If (present(velocities)) Then
                  Do ip = 1, 3
                    ddyn_nac(3*(iatom1-1)+i,3*(iatom2-1)+j,ip)=&
                        tmp1*born(ip,j,iatom2)+tmp2*born(ip,i,iatom1)-&
                        2.d0*tmp1*tmp2*dot_product(epsilon(ip,:),q_nac)/tmp3
                  End Do
                  ddyn_nac(3*(iatom1-1)+i,3*(iatom2-1)+j,:)=&
                       ddyn_nac(3*(iatom1-1)+i,3*(iatom2-1)+j,:)/&
                       mm(iatom1,iatom2)
                End If
              End Do
            End Do
          End Do
        End Do
! Convert to THz^2 units and normalize by volume and dielectric screening
        dyn_nac = thz2amua3*dyn_nac/tmp3/vol
        If (present(velocities)) Then
          ddyn_nac = thz2amua3*ddyn_nac/tmp3/vol
        End If

! Transform non-analytic correction from q-space to real space
! This gives a correction to the short-range force constants
        Do iatom1 = 1, natoms
          Do iatom2 = 1, natoms
            Do i = 1, 3
              Do j = 1, 3
                fc_diel(iatom1,i,:,:,:,iatom2,j) = real(dyn_nac(3*(iatom1-1)+i, &
                    3*(iatom2-1)+j))
              End Do
            End Do
          End Do
        End Do
! Normalize by supercell size (average over all unit cells)
        fc_diel = fc_diel/(nsize(1)*nsize(2)*nsize(3))
      End If

! Combine short-range and long-range (dielectric) force constants
      fc_total = fc_short + fc_diel

! Build the dynamical matrix
      Do iatom1 = 1, natoms
        Do iatom2 = 1, natoms
          Do ix1 = 1, nsize(1)
            Do iy1 = 1, nsize(2)
              Do iz1 = 1, nsize(3)
! Calculate relative position vector between atoms
! rcell is the cell vector for unit cell (ix1,iy1,iz1)
                rcell = matmul(latvec, (/ix1,iy1,iz1/) - (/1,1,1/) )
                r = positions(:, iatom1) - positions(:, iatom2) + rcell

! Find all periodic images with equal minimum distance
! This handles cases where multiple images are at the same distance
                dmin = huge(dmin)
                neq = 0
! Search over nearby supercells (±2 in each direction)
                Do ix2 = -2, 2
                  Do iy2 = -2, 2
                    Do iz2 = -2, 2
! Lattice translation vector
                      rl = ix2*nsize(1)*latvec(:,1)+iy2*nsize(2)*latvec(:,2)+&
                           iz2*nsize(3)*latvec(:,3)
                      rnorm = dnrm2(3, rl+r, 1) ! Distance to periodic image

! Check if this is a new minimum distance
                      If (abs(rnorm-dmin)>eps5) Then
                        If (rnorm<dmin) Then
! New minimum found, reset counter
                          neq = 1
                          dmin = rnorm
                          qr(neq) = dot_product(qspace(:,iq), rl+r)
                          If (present(velocities)) rr(:, neq) = rl + r
                        End If
                      Else
! Equal distance found, add to list
                        neq = neq + 1
                        qr(neq) = dot_product(qspace(:,iq), rl+r)
                        If (present(velocities)) rr(:, neq) = rl + r
                      End If
                    End Do
                  End Do
                End Do

! Sum over all equal-distance images
! The phase factor exp(-iq·R) accounts for Bloch theorem
                star = 0.D0
                Do ip = 1, neq
                  ztmp = phexp(-qr(ip))/neq ! Phase factor, averaged over equal distances
                  star = star + ztmp
                  Do i = 1, 3
                    Do j = 1, 3
! Add contribution to dynamical matrix
! Note: fc_total indices are swapped (iatom2,iatom1) for Hermiticity
                      dyn_total(3*(iatom1-1)+i,3*(iatom2-1)+j) = &
                            dyn_total(3*(iatom1-1)+i,3*(iatom2-1)+j)+&
                            ztmp*fc_total(iatom2,j,ix1,iy1,iz1,iatom1,i)

                      If (present(velocities)) Then
                        ddyn_total(3*(iatom1-1)+i,3*(iatom2-1)+j,:) = &
                            ddyn_total(3*(iatom1-1)+i,3*(iatom2-1)+j,:) - &
                            iunit*ztmp*rr(:,ip)*fc_total(iatom2,j,ix1,iy1,iz1,iatom1,i)
                      End If
                    End Do
                  End Do
                End Do

! Add NAC derivative contribution
                If (present(velocities) .And. nonanalytic .And. (.Not. all(abs(q_nac)<1.0D-8))) Then
                  Do i = 1, 3
                    Do j = 1, 3
                      ddyn_total(3*(iatom1-1)+i,3*(iatom2-1)+j,:) = &
                           ddyn_total(3*(iatom1-1)+i,3*(iatom2-1)+j,:) + &
                           star*ddyn_nac(3*(iatom1-1)+i,3*(iatom2-1)+j,:) / &
                           (nsize(1)*nsize(2)*nsize(3))
                    End Do
                  End Do
                End If
              End Do
            End Do
          End Do
        End Do
      End Do

! Diagonalize dynamical matrix to obtain phonon frequencies
! The dynamical matrix is Hermitian, so we use LAPACK zheev
! First call with lwork=-1 queries optimal work array size
      Call zheev('V', 'U', nbands, dyn_total, nbands, omega2, work, -1, rwork, i)
! "V" = compute eigenvectors, "U" = upper triangular storage

! Allocate work array with optimal size (with some safety margin)
      If (real(work(1))>nwork) Then
        nwork = nint(2*real(work(1)))
        Deallocate (work)
        Allocate (work(nwork))
      End If
! Actual diagonalization
      Call zheev('V', 'U', nbands, dyn_total, nbands, omega2, work, nwork, rwork, i)

! Store eigenvectors if requested
! Note: zheev returns eigenvectors as columns, we transpose to rows
      If (present(eigenvecs)) Then
        eigenvecs(iq, :, :) = transpose(dyn_total)
      End If

! Convert eigenvalues (squared frequencies) to frequencies
! omega2 contains squared angular frequencies
! Imaginary frequencies (unstable modes) are returned as negative
! This is conventional in phonon calculations
      omegas(iq, :) = sign(sqrt(abs(omega2)), omega2)

      If (present(velocities)) Then
        Do i = 1, nbands
          Do j = 1, 3
            velocities(iq, i, j) = real(dot_product(dyn_total(:,i), &
                matmul(ddyn_total(:,:,j), dyn_total(:,i))))
          End Do
! Normalize by 2*omega
! Avoid division by zero
          If (abs(omegas(iq,i))>eps5) Then
            velocities(iq, i, :) = velocities(iq, i, :)/(2.D0*omegas(iq,i))
          Else
            velocities(iq, i, :) = 0.D0
          End If
        End Do
      End If
    End Do

    Deallocate (mm, omega2, rwork, fc_diel, fc_total)
    Deallocate (dyn_total, dyn_nac, work, shortest, qr)
    If (allocated(ddyn_total)) Deallocate (ddyn_total, ddyn_nac, rr)

  End Subroutine dmsolver
End Module spectra
