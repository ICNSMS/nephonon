!=============================================================================
! Second-order Force Constants calculation via NEP
!=============================================================================
Module calc_fc2_mod
  Implicit None
  Private
  Public :: run_calc_fc2

  Interface
    Function nep_new(filename, len) Bind (C, Name='nep_new')
      Use iso_c_binding
      Type (c_ptr) :: nep_new
      Character (Kind=c_char), Dimension (*), Intent (In) :: filename
      Integer (Kind=c_int), Value :: len
    End Function nep_new

    Subroutine nep_delete(ptr) Bind (C, Name='nep_delete')
      Use iso_c_binding
      Type (c_ptr), Value :: ptr
    End Subroutine nep_delete

    Subroutine nep_compute(ptr, n_atoms, type_arr, box, position, potential, force, virial) Bind (C, Name='nep_compute')
      Use iso_c_binding
      Type (c_ptr), Value :: ptr
      Integer (Kind=c_int), Value :: n_atoms
      Integer (Kind=c_int), Dimension (*), Intent (In) :: type_arr
      Real (Kind=c_double), Dimension (*), Intent (In) :: box
      Real (Kind=c_double), Dimension (*), Intent (In) :: position
      Real (Kind=c_double), Dimension (*), Intent (Out) :: potential
      Real (Kind=c_double), Dimension (*), Intent (Out) :: force
      Real (Kind=c_double), Dimension (*), Intent (Out) :: virial
    End Subroutine nep_compute
  End Interface

Contains
!===========================================================================
! Calculate 2nd-order force constants using NEP (finite differences)
!
! Generates a supercell, displaces each atom along Cartesian directions,
! calls the NEP to obtain forces, and computes force constants from
! central finite differences.
!===========================================================================
  Subroutine run_calc_fc2
    Use iso_c_binding
    Use variables, Only: natoms, ntypes, nsize, displace_delta, latvec, positions, nat
    Implicit None
    Integer, Allocatable :: types(:)
! natoms, ntypes from variables
! type_counts mapped to nat

! Supercell data
    Real (Kind=8) :: super_lat(3, 3)
    Real (Kind=8), Allocatable :: super_pos(:, :) ! (3, super_natoms)
    Integer, Allocatable :: super_types(:)
    Integer :: super_natoms

! NEP data
    Type (c_ptr) :: nep_ptr
    Real (Kind=c_double), Allocatable :: forces_flat(:), potential(:), virial_flat(:)
    Real (Kind=c_double), Allocatable :: pos_flat(:)
    Real (Kind=c_double), Allocatable :: f_plus(:, :), f_minus(:, :)

! Force Constants Matrix: FC(3, 3, n_resp, n_disp)
    Real (Kind=8), Allocatable :: fc(:, :, :, :)

! Loop variables
    Integer :: i, j, k, n, m, c
    Integer :: ix, iy, iz, disp_dir
    Real (Kind=8) :: original_pos(3)
    Real (Kind=8) :: phi


    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Starting calculating 2nd Force Constants based on NEP ...       '
    Write (*, '(a)') '================================================================'

! ---------------------------------------------------------
! 1. Use Parameters from variables module
! ---------------------------------------------------------
    Write (*, '(3(a,i0))') '           Supercell size: ', nsize(1), ' x ', nsize(2), ' x ', nsize(3)
    Write (*, '(a,f0.2)') '       Displacement Delta: ', displace_delta
    Write (*, '(a,i0)') '                    Atoms: ', natoms
    Write (*, '(a,i0)') '                    Types: ', ntypes
! ---------------------------------------------------------
! 2. Prepare Atomic Data
! ---------------------------------------------------------

    Allocate (types(natoms))
! Assign types based on nat array
    c = 0
    Do i = 1, ntypes
      Do j = 1, nat(i)
        c = c + 1
        types(c) = i - 1 ! 0-based index for NEP
      End Do
    End Do

! ---------------------------------------------------------
! 3. Generate Supercell
! ---------------------------------------------------------
    super_natoms = natoms*nsize(1)*nsize(2)*nsize(3)
    Allocate (super_pos(3,super_natoms))
    Allocate (super_types(super_natoms))

    super_lat(1, :) = latvec(:, 1)*nsize(1)
    super_lat(2, :) = latvec(:, 2)*nsize(2)
    super_lat(3, :) = latvec(:, 3)*nsize(3)

! Fill supercell atoms
    c = 0
    Do n = 1, natoms
      Do iz = 0, nsize(3) - 1
        Do iy = 0, nsize(2) - 1
          Do ix = 0, nsize(1) - 1
            c = c + 1
            super_types(c) = types(n)
! Position: p + ix*a + iy*b + iz*c
            super_pos(:, c) = positions(:, n) &
                            + ix*latvec(:, 1) + iy*latvec(:, 2) + iz*latvec(:, 3)
          End Do
        End Do
      End Do
    End Do

! ---------------------------------------------------------
! 4. Initialize NEP
! ---------------------------------------------------------
    Write (*, '(a)')
    Write (*, '(a)') '=================== Information From NEP ======================='
    nep_ptr = nep_new('nep.txt'//c_null_char, 7)
    If (.Not. c_associated(nep_ptr)) Then
      Write (*, '(a)') 'Error: make sure nep.txt exists.'
      Stop
    End If
    Write (*, '(a)') '================================================================'
    Write (*, '(a)')
! ---------------------------------------------------------
! 5. Calculate Force Constants (Finite Difference)
! ---------------------------------------------------------
    Allocate (forces_flat(3*super_natoms))
    Allocate (potential(super_natoms))
    Allocate (virial_flat(9*super_natoms))
    Allocate (pos_flat(3*super_natoms))

! Compute forces for positive/negative displacements.

    Allocate (f_plus(3,super_natoms))
    Allocate (f_minus(3,super_natoms))
    Allocate (fc(3,3,super_natoms,super_natoms))
    fc = 0.0D0

    Write (*, '(a)') 'Starting calculation of Force Constants...'

    Do n = 1, super_natoms ! Iterate over ALL atoms in supercell (as displacement source)
      If (mod(n,10)==0) Then
        Write (*, '(a,i3,a)') '  Processing atom: ', 100*n/super_natoms, '%'
      End If

      Do disp_dir = 1, 3 ! x, y, z directions                
! --- Positive Displacement ---
        original_pos = super_pos(:, n)
        super_pos(disp_dir, n) = original_pos(disp_dir) + displace_delta

! Pack positions for NEP (x... y... z...)
        pos_flat(1:super_natoms) = super_pos(1, :)
        pos_flat(super_natoms+1:2*super_natoms) = super_pos(2, :)
        pos_flat(2*super_natoms+1:3*super_natoms) = super_pos(3, :)

        Call nep_compute(nep_ptr, super_natoms, super_types, super_lat, pos_flat, &
                                 potential, forces_flat, virial_flat)

! Unpack forces (NEP returns fx... fy... fz...)
        f_plus(1, :) = forces_flat(1:super_natoms)
        f_plus(2, :) = forces_flat(super_natoms+1:2*super_natoms)
        f_plus(3, :) = forces_flat(2*super_natoms+1:3*super_natoms)

! --- Negative Displacement ---
        super_pos(disp_dir, n) = original_pos(disp_dir) - displace_delta

! Pack positions
        pos_flat(1:super_natoms) = super_pos(1, :)
        pos_flat(super_natoms+1:2*super_natoms) = super_pos(2, :)
        pos_flat(2*super_natoms+1:3*super_natoms) = super_pos(3, :)

        Call nep_compute(nep_ptr, super_natoms, super_types, super_lat, pos_flat, &
                                 potential, forces_flat, virial_flat)

! Unpack forces
        f_minus(1, :) = forces_flat(1:super_natoms)
        f_minus(2, :) = forces_flat(super_natoms+1:2*super_natoms)
        f_minus(3, :) = forces_flat(2*super_natoms+1:3*super_natoms)

! --- Restore Position ---
        super_pos(:, n) = original_pos

! --- Calculate force constants ---
        Do m = 1, super_natoms
          Do k = 1, 3
! Force constant Phi(m, n)_k,disp_dir = - dF_m^k / dR_n^disp_dir
            phi = -(f_plus(k,m)-f_minus(k,m))/(2.0D0*displace_delta)
            fc(k, disp_dir, m, n) = phi
          End Do
        End Do

      End Do
    End Do

    Call nep_delete(nep_ptr)

! ---------------------------------------------------------
! 6. Write FORCE_CONSTANTS in Phonopy format
! ---------------------------------------------------------
    Open (Unit=20, File='FORCE_CONSTANTS', Status='replace')

! Header: natom natom
    Write (20, '(i0,1x,i0)') super_natoms, super_natoms

    Do i = 1, super_natoms ! Responding atom (Row block index)
      Do j = 1, super_natoms ! Displaced atom (Column block index)
! Block header: i j
        Write (20, '(i0,1x,i0)') i, j
! Matrix 3x3
! Row 1: xx xy xz
        Write (20, '(3ES24.15E3)') fc(1, 1, i, j), fc(1, 2, i, j), fc(1, 3, i, j)
! Row 2: yx yy yz
        Write (20, '(3ES24.15E3)') fc(2, 1, i, j), fc(2, 2, i, j), fc(2, 3, i, j)
! Row 3: zx zy zz
        Write (20, '(3ES24.15E3)') fc(3, 1, i, j), fc(3, 2, i, j), fc(3, 3, i, j)
      End Do
    End Do
    Close (20)

    Write (*, '(a)') 'FORCE_CONSTANTS Calculation finished.'
    Write (*, '(a)')
  End Subroutine run_calc_fc2
End Module calc_fc2_mod
