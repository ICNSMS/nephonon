!=============================================================================
! Neutron Scattering Calculation Utilities
! Contains common routines for both single crystal and powder calculations
!=============================================================================

Module sqw_util
  Implicit None
  Private
  Public :: rmsdcalc, sqw_givenq

Contains

! Mean-square displacement (MSD) calculator
  Subroutine rmsdcalc(t)

    Use spectra, Only: dmsolver
    Use func, Only: fbe
    Use constants, Only: hbar, ps2s, amu, a2m, thz2mev, eps4
    Use variables, Only: dw_qmesh, natoms, nbands, &
                         armsd, rlatvec, masses2

    Implicit None

    Real (Kind=8), Intent (In) :: t
    Integer (Kind=4) :: ntot, ii, jj, kk, ll
    Real (Kind=8), Allocatable :: qzone(:, :), omegas(:, :), amsd(:, :)
    Complex (Kind=8), Allocatable :: eigenvecs(:, :, :)

    If (.Not. allocated(armsd)) Allocate (armsd(3,natoms))

    ntot = dw_qmesh(1)*dw_qmesh(2)*dw_qmesh(3)
    Allocate (qzone(3,ntot))
    Allocate (omegas(ntot,nbands))
    Allocate (eigenvecs(ntot,nbands,nbands))
    Allocate (amsd(3,natoms))
    omegas = 0.D0
    eigenvecs = 0.D0
    amsd = 0.D0

! Discretize q-points along reciprocal directions (Gamma-centered mesh)
    ll = 0
    Do ii = 1, dw_qmesh(1)
      Do jj = 1, dw_qmesh(2)
        Do kk = 1, dw_qmesh(3)
          ll = ll + 1
          qzone(:, ll) = rlatvec(:,1)*(ii-1.d0)/dw_qmesh(1) &
                       + rlatvec(:,2)*(jj-1.d0)/dw_qmesh(2) &
                       + rlatvec(:,3)*(kk-1.d0)/dw_qmesh(3)
        End Do
      End Do
    End Do

! Calculate phonon frequencies and eigenvectors
    Call dmsolver(qzone, omegas, eigenvecs, verbose=.True.)

! MSD calculation
    Do ii = 1, natoms
      Do jj = 1, 3
        Do kk = 1, nbands
          Do ll = 1, ntot
            If (omegas(ll,kk)<eps4) Cycle
            amsd(jj, ii) = amsd(jj,ii)+hbar/ntot/masses2(ii)/&
                           omegas(ll,kk)*(0.5d0+fBE(omegas(ll,kk),T))*&
                           abs(eigenvecs(ll,kk,((ii-1)*3+jj)))**2
          End Do
        End Do
      End Do
    End Do

    amsd = amsd*ps2s/amu/(a2m**2)
    armsd = sqrt(amsd)

    Deallocate (qzone, omegas, eigenvecs, amsd)
  End Subroutine rmsdcalc

! Calculate S(Q, E) at given Q-point
! Computes single-phonon emission contribution
  Subroutine sqw_givenq(qpt, omegas, rmsd, eigenvecs, sqwtemp, t)
    Use func, Only: fbemev
    Use constants, Only: iunit, eps3
    Use variables, Only: natoms, nbands, &
                         masses2, coh_b2, lphase, &
                         positions
    Implicit None
    Real (Kind=8), Intent (In) :: t, qpt(:), omegas(:), rmsd(:, :)
    Real (Kind=8), Intent (Out) :: sqwtemp(:)
    Complex (Kind=8), Intent (In) :: eigenvecs(:, :)

    Integer (Kind=4) :: ii, jj
    Real (Kind=8) :: dwfac
    Complex (Kind=8) :: temp, tempsum

    sqwtemp = 0.D0

    Do ii = 1, nbands
      If (omegas(ii)<eps3) Cycle
      tempsum = 0.D0
      Do jj = 1, natoms
        dwfac = 0.5D0*dot_product(qpt, rmsd(:,jj))**2
        If (lphase) Then
          temp = coh_b2(jj)/sqrt(masses2(jj))*&
                 dot_product(qpt, eigenvecs(ii,((jj-1)*3+1):((jj-1)*3+3)))&
                 *exp(iunit*dot_product(qpt, positions(:,jj))-DWfac)
        Else
          temp = coh_b2(jj)/sqrt(masses2(jj))*exp(-DWfac)*&
                 dot_product(qpt, eigenvecs(ii,((jj-1)*3+1):((jj-1)*3+3)))
        End If
        tempsum = tempsum + temp
      End Do
      sqwtemp(ii) = abs(tempsum)**2*(fbemev(omegas(ii),t)+1.D0)/omegas(ii)
    End Do
  End Subroutine sqw_givenq
End Module sqw_util
