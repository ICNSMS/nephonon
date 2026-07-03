!=============================================================================
! Output Manager Module
!
! This module handles all file output operations for the phonon code.
! It centralizes writing routines for band structure, DOS, and isosurfaces.
! All routines use consistent units (energies in meV).
!=============================================================================

Module output
  Use constants, Only: thz2mev
  Implicit None
  Private
  Public :: write_phononband
  Public :: write_phononvect
  Public :: write_phononbandvelocity
  Public :: write_phonondos
  Public :: write_phonondosvelocity
  Public :: write_phononsurface
  Public :: write_sqw_intensity
  Public :: write_sqw_powder

Contains

!===========================================================================
! Write phonon band structure to phononband.dat
!===========================================================================
  Subroutine write_phononband(nqtot, nbands, qdist, omegas)
    Integer (Kind=4), Intent (In) :: nqtot, nbands
    Real (Kind=8), Intent (In) :: qdist(nqtot)
    Real (Kind=8), Intent (In) :: omegas(nqtot, nbands)
    Integer (Kind=4) :: iq, iband

    Write (*, '(a)') 'Writing band structure to phononband.dat ...'
    Open (1, File='phononband.dat', Status='replace')
    Write (1, '(2a17)') '#qpath', 'Energy(meV)'
    Do iband = 1, nbands
      Do iq = 1, nqtot
        Write (1, '(2(1x,es17.10))') qdist(iq), omegas(iq, iband)
      End Do
      Write (1, *)
    End Do
    Close (1)
  End Subroutine write_phononband

!===========================================================================
! Write phonon eigenvectors (Band or DOS)
!===========================================================================
  Subroutine write_phononvect(filename, nqtot, nbands, natoms, qfrac, omegas, eigenvecs, masses2)
    Character (Len=*), Intent (In) :: filename
    Integer (Kind=4), Intent (In) :: nqtot, nbands, natoms
    Real (Kind=8), Intent (In) :: qfrac(3, nqtot)
    Real (Kind=8), Intent (In) :: omegas(nqtot, nbands)
    Complex (Kind=8), Intent (In) :: eigenvecs(nqtot, nbands, nbands) ! Dimensions might need check
    Real (Kind=8), Intent (In) :: masses2(natoms)

    Integer (Kind=4) :: iq, iband, iatom, idim
    Real (Kind=8) :: freq_thz, freq_cm1
    Complex (Kind=8) :: ev_normalized(3)

    Write (*, '(a,a)') 'Writing eigenvectors to ', filename
    Open (2, File=filename, Status='replace')

    Do iq = 1, nqtot
      Write (2, '(A)') '     diagonalizing the dynamical matrix ...'
      Write (2, '(A)')
! Write q-point
      Write (2, '(A,3F12.4)') ' q =', qfrac(1, iq), qfrac(2, iq), qfrac(3, iq)
      Write (2, '(A)') ' *****************************************************************************'

! Write frequencies and eigenvectors for each band
      Do iband = 1, nbands
        freq_thz = omegas(iq, iband)/thz2mev
        freq_cm1 = freq_thz*33.356409519815D0

        Write (2, '(A,I5,A,F15.6,A,F15.6,A)') "     freq (", iband, ") =", &
               freq_thz, " [THz] =", freq_cm1, " [cm-1]"

! Write eigenvector for each atom (normalize by sqrt(mass))
! Note: eigenvecs shape assumed (nqtot, nbands, 3*natoms) 
! The caller usually passes eigenvecs(nqtot, nbands, nbands) where nbands=3*natoms
        Do iatom = 1, natoms
          Do idim = 1, 3
            ev_normalized(idim) = eigenvecs(iq, iband, 3*(iatom-1)+idim)/sqrt(masses2(iatom))
          End Do
          Write (2, '(A,6F12.6,A)') " (", &
                  real(ev_normalized(1)), aimag(ev_normalized(1)), &
                  real(ev_normalized(2)), aimag(ev_normalized(2)), &
                  real(ev_normalized(3)), aimag(ev_normalized(3)), "   )"
        End Do
      End Do
      Write (2, '(A)') ' *****************************************************************************'
    End Do
    Close (2)
  End Subroutine write_phononvect

!===========================================================================
! Write phonon band velocities to phononbandvelocity.dat
!===========================================================================
  Subroutine write_phononbandvelocity(nqtot, nbands, qdist, omegas, velocities, velocities_xyz)
    Integer (Kind=4), Intent (In) :: nqtot, nbands
    Real (Kind=8), Intent (In) :: qdist(nqtot)
    Real (Kind=8), Intent (In) :: omegas(nqtot, nbands)
    Real (Kind=8), Intent (In) :: velocities(nqtot, nbands)
    Real (Kind=8), Intent (In) :: velocities_xyz(nqtot, nbands, 3)
    Integer (Kind=4) :: iq, iband

    Write (*, '(a)') 'Writing group velocities to phononbandvelocity.dat ...'
    Open (3, File='phononbandvelocity.dat', Status='replace')
! Header
    Write (3, '(6a17)') '#qdist', 'Energy(meV)', 'Velocity', 'Vx', 'Vy', 'Vz'

    Do iband = 1, nbands
      Do iq = 1, nqtot
        Write (3, '(6(1x,es17.10))') qdist(iq), omegas(iq, iband), velocities(iq, iband), &
               velocities_xyz(iq, iband, 1), &
               velocities_xyz(iq, iband, 2), &
               velocities_xyz(iq, iband, 3)
      End Do
! Empty line between bands
      Write (3, *)
    End Do
    Close (3)
  End Subroutine write_phononbandvelocity

!===========================================================================
! Write phonon DOS to phonondos.dat
!===========================================================================
  Subroutine write_phonondos(nomega, nwidths, dos_omega, dos_values)
    Integer (Kind=4), Intent (In) :: nomega, nwidths
    Real (Kind=8), Intent (In) :: dos_omega(nomega)
    Real (Kind=8), Intent (In) :: dos_values(nomega, nwidths)
    Integer (Kind=4) :: iomega, iwidth

    Write (*, '(a)') 'Writing DOS to phonondos.dat'
    Open (1, File='phonondos.dat', Status='replace')
! Write header comment
    Write (1, '(A)') '# Frequency(meV)  DOS(width=0.1~1.0)'
    Do iomega = 1, nomega
      Write (1, '(11(1x,es17.10))') dos_omega(iomega), (dos_values(iomega,iwidth), iwidth=1, nwidths)
    End Do
    Close (1)
  End Subroutine write_phonondos

!===========================================================================
! Write phonon DOS velocities to phonondosvelocity.dat
!===========================================================================
  Subroutine write_phonondosvelocity(nqtot, nbands, omegas, velocities_xyz)
    Integer (Kind=4), Intent (In) :: nqtot, nbands
    Real (Kind=8), Intent (In) :: omegas(nqtot, nbands)
    Real (Kind=8), Intent (In) :: velocities_xyz(nqtot, nbands, 3)
    Integer (Kind=4) :: iq, iband
    Real (Kind=8) :: vabs

    Write (*, '(a)') 'Writing group velocities to phonondosvelocity.dat'
    Open (3, File='phonondosvelocity.dat', Status='replace')
    Write (3, '(5a17)') '#Energy(meV)', 'Velocity', 'Vx', 'Vy', 'Vz'

    Do iband = 1, nbands
      Do iq = 1, nqtot
        vabs = sqrt(sum(velocities_xyz(iq,iband,:)**2))

! Output format: Energy Velocity Vx Vy Vz
        Write (3, '(5(1x,es17.10))') omegas(iq, iband), vabs, &
                               velocities_xyz(iq, iband, 1), &
                               velocities_xyz(iq, iband, 2), &
                               velocities_xyz(iq, iband, 3)
      End Do
! Empty line between bands
      Write (3, *)
    End Do
    Close (3)
  End Subroutine write_phonondosvelocity

!===========================================================================
! Write phonon isosurface to phononsurface.fs
!===========================================================================
  Subroutine write_phononsurface(isosurface_qmesh, nbands, rlatvec, omegas, q_index)
    Integer (Kind=4), Intent (In) :: isosurface_qmesh(3)
    Integer (Kind=4), Intent (In) :: nbands
    Real (Kind=8), Intent (In) :: rlatvec(3, 3)
    Real (Kind=8), Intent (In) :: omegas(:, :) ! (nqtot, nbands)
    Integer (Kind=4), Intent (In) :: q_index(isosurface_qmesh(1), isosurface_qmesh(2), isosurface_qmesh(3))
    Integer (Kind=4) :: iband, ik1, ik2, ik3, iq

    Write (*, '(a)') 'Writing isosurface data to phononsurface.fs ...'
    Open (10, File='phononsurface.fs', Status='replace')

! Write k-grid dimensions
    Write (10, '(3(1x,i0))') isosurface_qmesh(1), isosurface_qmesh(2), isosurface_qmesh(3)

! Write grid type (0 = Monkhorst-Pack grid)
    Write (10, '(a)') ' 0'

! Write number of bands
    Write (10, '(1x,i0)') nbands

! Write reciprocal lattice vectors (3x3 matrix, one vector per line)
! Convert to single precision for FermiSurfer compatibility
    Write (10, '(3(1x,es17.10))') real(rlatvec(1,1), kind=4), real(rlatvec(2,1), kind=4), real(rlatvec(3,1), kind=4)
    Write (10, '(3(1x,es17.10))') real(rlatvec(1,2), kind=4), real(rlatvec(2,2), kind=4), real(rlatvec(3,2), kind=4)
    Write (10, '(3(1x,es17.10))') real(rlatvec(1,3), kind=4), real(rlatvec(2,3), kind=4), real(rlatvec(3,3), kind=4)

! Write isosurface value
! Note: Phonon code uses 0-based indexing for bands in logic, but here we loop 1..nbands
! Just write the frequency data. FermiSurfer will slice it.

    Do iband = 1, nbands
      Do ik3 = 1, isosurface_qmesh(3)
        Do ik2 = 1, isosurface_qmesh(2)
          Do ik1 = 1, isosurface_qmesh(1)
            iq = q_index(ik1, ik2, ik3)
            Write (10, '(1x,es17.10)') omegas(iq, iband)
          End Do
        End Do
      End Do
    End Do

    Close (10)
  End Subroutine write_phononsurface

!=========================================================================== 
! Write S(Q,E) intensity to sqw_crystal.dat
!===========================================================================
  Subroutine write_sqw_intensity(nq, ne_bins, e_min, e_max, sqwsum, qdist)
    Integer (Kind=4), Intent (In) :: nq, ne_bins
    Real (Kind=8), Intent (In) :: e_min, e_max
    Real (Kind=8), Intent (In) :: sqwsum(ne_bins, nq)
    Real (Kind=8), Intent (In), Optional :: qdist(nq)

    Integer (Kind=4) :: jj, kk
    Real (Kind=8) :: energy, q_val

    Write (*, '(a)') 'Write S(Q,E) into sqw_crystal.dat ...'
    Open (1, File='sqw_crystal.dat', Status='replace')
    Write (1, '(3a17)') '#Qpath', 'Energy(meV)', 'S(Q,E)'
    Do jj = 1, nq
      If (present(qdist)) Then
        q_val = qdist(jj)
      Else
        q_val = 0.0D0 ! Should not happen in path mode
      End If
      Do kk = 1, ne_bins
        If (ne_bins>1) Then
          energy = e_min + (e_max-e_min)*dble(kk-1)/dble(ne_bins-1)
        Else
          energy = e_min
        End If
        Write (1, '(3(1x,es17.10))') q_val, energy, sqwsum(kk, jj)
      End Do
      Write (1, *) ! Blank line for plot compatibility
    End Do
    Close (1)
  End Subroutine write_sqw_intensity

!=========================================================================== 
! Write S(Q,E) intensity to sqw_powder.dat
!===========================================================================
  Subroutine write_sqw_powder(nq, ne_bins, e_min, e_max, sqwsum, qdist)
    Integer (Kind=4), Intent (In) :: nq, ne_bins
    Real (Kind=8), Intent (In) :: e_min, e_max
    Real (Kind=8), Intent (In) :: sqwsum(ne_bins, nq)
    Real (Kind=8), Intent (In), Optional :: qdist(nq)

    Integer (Kind=4) :: jj, kk
    Real (Kind=8) :: energy, q_val

    Write (*, '(a)') 'Write S(|Q|,E) into sqw_powder.dat ...'
    Open (1, File='sqw_powder.dat', Status='replace')
    Write (1, '(3a17)') '#Qpath', 'Energy(meV)', 'S(|Q|,E)'
    Do jj = 1, nq
      If (present(qdist)) Then
        q_val = qdist(jj)
      Else
        q_val = 0.0D0 ! Should not happen in path mode
      End If
      Do kk = 1, ne_bins
        If (ne_bins>1) Then
          energy = e_min + (e_max-e_min)*dble(kk-1)/dble(ne_bins-1)
        Else
          energy = e_min
        End If
        Write (1, '(3(1x,es17.10))') q_val, energy, sqwsum(kk, jj)
      End Do
      Write (1, *) ! Blank line for plot compatibility
    End Do
    Close (1)
  End Subroutine write_sqw_powder
End Module output
