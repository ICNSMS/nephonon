!=============================================================================
! Symmetrization module for phonon calculations
!
! This module handles the symmetrization of force constants including:
!   - Translational invariance (Acoustic Sum Rule)
!   - Permutation symmetry
!   - Charge neutrality of Born effective charges
!=============================================================================

Module symmetrization

  Use variables, Only: nsize, natoms, fc_short, born
  Implicit None
  Private
  Public :: symmetrize_force_constants, enforce_charge_neutrality

Contains

!===========================================================================
! Symmetrize force constants
!
! Iteratively applies translational invariance and permutation symmetry
!
! Inputs:
!   level - Number of iterations (default: 10).
! Effects:
!   Modifies fc_short in place to satisfy invariance and symmetry.
!===========================================================================
  Subroutine symmetrize_force_constants(level)

    Integer (Kind=4), Intent (In), Optional :: level
    Integer (Kind=4) :: niter, i

    niter = 10
    If (present(level)) niter = level

    Write (*, '(a,i0,a)') '  Symmetrizing force constants with level ', niter, '...'

    Do i = 1, niter
      Call set_translational_invariance()
      Call set_permutation_symmetry()
    End Do
    Call set_translational_invariance()

  End Subroutine symmetrize_force_constants

!===========================================================================
! Enforce translational invariance (Acoustic Sum Rule)
!
! Enforces the Acoustic Sum Rule:
!   - sum_i Phi_ij = 0
!   - sum_j Phi_ij = 0
!===========================================================================
  Subroutine set_translational_invariance()

    Integer (Kind=4) :: i, j, alpha, beta
    Integer (Kind=4) :: lx, ly, lz
    Real (Kind=8) :: sum_val, avg_val
    Integer (Kind=4) :: total_cells

    total_cells = nsize(1)*nsize(2)*nsize(3)

! Step 1: sum_i Phi_ij = 0
! For each j, alpha, beta, sum over i and R
    Do j = 1, natoms
      Do beta = 1, 3
        Do alpha = 1, 3
          sum_val = 0.0D0

! Sum over all i and all cells
          Do i = 1, natoms
            Do lx = 1, nsize(1)
              Do ly = 1, nsize(2)
                Do lz = 1, nsize(3)
                  sum_val = sum_val + fc_short(i, alpha, lx, ly, lz, j, beta)
                End Do
              End Do
            End Do
          End Do

! Calculate average correction
          avg_val = sum_val/(total_cells*natoms)

! Subtract average from each element
          Do i = 1, natoms
            Do lx = 1, nsize(1)
              Do ly = 1, nsize(2)
                Do lz = 1, nsize(3)
                  fc_short(i, alpha, lx, ly, lz, j, beta) = fc_short(i, alpha, lx, ly, lz, j, beta) - avg_val
                End Do
              End Do
            End Do
          End Do

        End Do
      End Do
    End Do

! Step 2: sum_j Phi_ij = 0
! For each i, alpha, beta, sum over j and R
    Do i = 1, natoms
      Do alpha = 1, 3
        Do beta = 1, 3
          sum_val = 0.0D0

          Do lx = 1, nsize(1)
            Do ly = 1, nsize(2)
              Do lz = 1, nsize(3)
                Do j = 1, natoms
                  sum_val = sum_val + fc_short(i, alpha, lx, ly, lz, j, beta)
                End Do
              End Do
            End Do
          End Do

! Subtract sum from self-interaction term (i, i, R=0)
! In Fortran (1-based), R=0 corresponds to (1, 1, 1)
          fc_short(i, alpha, 1, 1, 1, i, beta) = fc_short(i, alpha, 1, 1, 1, i, beta) - sum_val

        End Do
      End Do
    End Do

  End Subroutine set_translational_invariance

!===========================================================================
! Enforce permutation symmetry
!
! Ensures Phi_ij(R) = Phi_ji(-R)^T
! i.e., fc(i, a, R, j, b) = fc(j, b, -R, i, a)
!===========================================================================
  Subroutine set_permutation_symmetry()

    Integer (Kind=4) :: i, j, lx, ly, lz, alpha, beta
    Integer (Kind=4) :: neg_lx, neg_ly, neg_lz
    Real (Kind=8) :: val1, val2, avg_val
    Logical :: process

    Do i = 1, natoms
      Do lx = 1, nsize(1)
        Do ly = 1, nsize(2)
          Do lz = 1, nsize(3)
            Do j = 1, natoms

! Calculate -R index (handling PBC)
! Indices are 1-based, so convert to 0-based, negate, mod, convert back
              neg_lx = mod(nsize(1)-(lx-1), nsize(1)) + 1
              neg_ly = mod(nsize(2)-(ly-1), nsize(2)) + 1
              neg_lz = mod(nsize(3)-(lz-1), nsize(3)) + 1

! Determine if we should process this pair to avoid double counting
              process = .False.
              If (i<j) Then
                process = .True.
              Else If (i>j) Then
                process = .False.
              Else ! i == j
                If (lx<neg_lx) Then
                  process = .True.
                Else If (lx>neg_lx) Then
                  process = .False.
                Else ! lx == neg_lx
                  If (ly<neg_ly) Then
                    process = .True.
                  Else If (ly>neg_ly) Then
                    process = .False.
                  Else ! ly == neg_ly
                    If (lz<neg_lz) Then
                      process = .True.
                    Else If (lz>neg_lz) Then
                      process = .False.
                    Else ! lz == neg_lz (R = -R)
                      process = .True.
                    End If
                  End If
                End If
              End If

              If (process) Then
                Do alpha = 1, 3
                  Do beta = 1, 3

                    val1 = fc_short(i, alpha, lx, ly, lz, j, beta)
                    val2 = fc_short(j, beta, neg_lx, neg_ly, neg_lz, i, alpha)

                    avg_val = (val1+val2)/2.0D0

                    fc_short(i, alpha, lx, ly, lz, j, beta) = avg_val
                    fc_short(j, beta, neg_lx, neg_ly, neg_lz, i, alpha) = avg_val

                  End Do
                End Do
              End If

            End Do
          End Do
        End Do
      End Do
    End Do

  End Subroutine set_permutation_symmetry

!===========================================================================
! Enforce charge neutrality for Born effective charges
!
! Ensures that sum_k Z*_k,ij = 0 for all i, j
!===========================================================================
  Subroutine enforce_charge_neutrality()

    Integer (Kind=4) :: i, j, k
    Real (Kind=8) :: sum_val, avg_val

    Write (*, '(a)') '  Enforcing charge neutrality for Born effective charges...'

    Do i = 1, 3 ! row
      Do j = 1, 3 ! col
        sum_val = 0.0D0

! Sum over all atoms
        Do k = 1, natoms
          sum_val = sum_val + born(i, j, k)
        End Do

! Calculate average correction
        avg_val = sum_val/natoms

! Subtract average from each atom's charge
        Do k = 1, natoms
          born(i, j, k) = born(i, j, k) - avg_val
        End Do
      End Do
    End Do

  End Subroutine enforce_charge_neutrality
End Module symmetrization
