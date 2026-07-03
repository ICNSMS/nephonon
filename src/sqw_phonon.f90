!=============================================================================
! Neutron Scattering Calculation Driver
! Contains main drivers for single crystal and powder calculations
!=============================================================================

Module sqw_phonon
  Use sqw_util, Only: rmsdcalc, sqw_givenq
  Use func, Only: gaussian_sigma_poly4
  Implicit None
  Private
  Public :: run_sqw_crystal
  Public :: run_sqw_powder

Contains

! Add a Gaussian peak to a 1D grid
  Subroutine add_gaussian_to_grid(accum, xgrid, center, sigma, amplitude)
    Use func, Only: gauss
    Implicit None
    Real (Kind=8), Intent (Inout) :: accum(:)
    Real (Kind=8), Intent (In) :: xgrid(:), center, sigma, amplitude
    Integer (Kind=4) :: i

    Do i = 1, size(xgrid)
      accum(i) = accum(i) + amplitude*gauss(xgrid(i), center, sigma)
    End Do
  End Subroutine add_gaussian_to_grid

! Generate a list of Q-points along band paths
! Coordinates are in conventional/primitive bases as indicated
  Subroutine load_qpoints()
    Use variables, Only: crlatvec, rlatvec, nqtot, &
                         qlist, pqlist, cqlist, &
                         elist, qdist, latvec, &
                         nband_paths, band_paths, band_npoints
    Use constants, Only: eps5, pi
    Use func, Only: cross_prod

    Implicit None

    Integer (Kind=4) :: ii, jj, kk, ll
    Integer (Kind=4) :: info, int_arr(3)
    Real (Kind=8) :: dist(3), work(9)
    Real (Kind=8) :: convert(3, 3)
    Real (Kind=8) :: tmp_latvec(3, 3), vol_tmp

! Path related variables
    Integer (Kind=4) :: ipath, iq
    Real (Kind=8) :: dq(3), current_q(3)
    Real (Kind=8), External :: dnrm2

! Calculate total number of Q points from BANDS_STRUCTURE
    If (nband_paths>0) Then
      nqtot = sum(band_npoints)
    Else
      Write (*, '(a)') 'Error: No BANDS_STRUCTURE found.'
      Stop
    End If

    If (allocated(qlist)) Deallocate (qlist)
    If (allocated(pqlist)) Deallocate (pqlist)
    If (allocated(cqlist)) Deallocate (cqlist)
    If (allocated(elist)) Deallocate (elist)
    If (allocated(qdist)) Deallocate (qdist)

    Allocate (qlist(3,nqtot))
    Allocate (pqlist(3,nqtot))
    Allocate (cqlist(3,nqtot))
    Allocate (elist(nqtot))
    Allocate (qdist(nqtot))

! Calculate crlatvec using primitive lattice vectors
    tmp_latvec = latvec

    Do ii = 1, 3
      jj = mod(ii, 3) + 1
      kk = mod(jj, 3) + 1
      Call cross_prod(tmp_latvec(:,jj), tmp_latvec(:,kk), crlatvec(:,ii))
    End Do
    vol_tmp = abs(dot_product(tmp_latvec(:,1),crlatvec(:,1)))
    crlatvec = 2.D0*pi*crlatvec/vol_tmp

! Calculate the conversion matrix from conventional to primitive basis
    convert = rlatvec
    Call dgetrf(3, 3, convert, 3, int_arr, info)
    Call dgetri(3, convert, 3, int_arr, work, 9, info)
    convert = matmul(convert, crlatvec)

! Generate Q-points along BANDS_STRUCTURE paths
    ii = 0
    ll = 0

    Do ipath = 1, nband_paths
      If (band_npoints(ipath)<2) Cycle
      dq = (band_paths(:,2,ipath)-band_paths(:,1,ipath))/real(band_npoints(ipath)-1, kind=8)

      Do iq = 1, band_npoints(ipath)
        ii = ii + 1
        current_q = band_paths(:, 1, ipath) + dq*real(iq-1, kind=8)
        qlist(:, ii) = current_q
        cqlist(:, ii) = matmul(crlatvec, current_q)
        pqlist(:, ii) = matmul(convert, current_q)

        ll = ll + 1
        If (ll<=nqtot) Then
          elist(ll) = ii
          If (ll==1) Then
            qdist(ll) = 0.D0
          Else
            dist = cqlist(:, ii) - cqlist(:, ii-1)
            qdist(ll) = qdist(ll-1) + dnrm2(3, dist, 1)
          End If
        End If
      End Do
    End Do
  End Subroutine load_qpoints

! S(Q, E) driver for single crystal
  Subroutine sqw_calc()
    Use constants, Only: tpi, thz2mev, eps5
    Use variables, Only: e_min, e_max, ne_bins, nqtot, &
                         temperature, sqwsum, omega, cqlist, &
                         nbands, e_smearing, eigenvec, armsd
    Use output, Only: write_sqw_intensity
    Implicit None
    Integer (Kind=4) :: ih, ii, jj, nq
    Real (Kind=8) :: ee(ne_bins), de, sig
    Real (Kind=8) :: sqwtemp(nbands)

    nq = nqtot ! Use the total number of Q points

    If (allocated(sqwsum)) Deallocate (sqwsum)
    Allocate (sqwsum(ne_bins,nq))
    sqwsum = 0.D0

    If (ne_bins>1) Then
      ee = (/ (e_min+(e_max-e_min)*dble(ii-1)/dble(ne_bins-1),ii=1,ne_bins) /)
      de = (e_max-e_min)/dble(ne_bins-1)
    Else
      ee = e_min
      de = 0.D0
    End If

    Write (*, '(a)') 'Calculate S(Q, E) ...'

    Do ih = 1, nq

      Call sqw_givenq(cqlist(:,ih), omega(ih,:), armsd(:,:), eigenvec(ih,:,:), sqwtemp, temperature)
      Do jj = 1, nbands
        sig = gaussian_sigma_poly4(omega(ih,jj), e_smearing, de)
        Call add_gaussian_to_grid(sqwsum(:,ih), ee, omega(ih,jj), sig, sqwtemp(jj))
      End Do
      If (mod(ih,1000)==0) Then
        Write (*, '(a,i4,a)') '  Progress:', int(ih*100./nq), '%'
      End If
    End Do

    Where (sqwsum<eps5) sqwsum = sqwsum + eps5
  End Subroutine sqw_calc

  Subroutine phoneigen()
    Use variables, Only: natoms, nqtot, nbands, omega, eigenvec, cqlist
    Use constants, Only: eps1, eps3, tpi, thz2mev
    Use spectra, Only: dmsolver
    Implicit None

    nbands = 3*natoms
    If (allocated(omega)) Deallocate (omega)
    If (allocated(eigenvec)) Deallocate (eigenvec)
    Allocate (omega(nqtot,nbands))
    Allocate (eigenvec(nqtot,nbands,nbands))

    omega = 0.D0
    eigenvec = 0.D0

    Call dmsolver(cqlist(:,:), omega(:,:), eigenvec(:,:,:))

    omega = omega/tpi*thz2mev

! Set all imaginary frequencies to zero
    If (any(omega<-eps1)) Then
      Write (*, '(a)') 'Warning: there exists imaginary frequency.'
      Write (*, *)
      Where (omega<0.D0) omega = 0.D0
      Where (omega<eps3) omega = omega + eps3
    End If
  End Subroutine phoneigen

  Subroutine run_sqw_crystal()
    Use variables, Only: temperature, nbands, nqtot
    Use output, Only: write_sqw_intensity
    Use variables, Only: e_min, e_max, ne_bins, sqwsum, qdist
    Implicit None

    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Starting neutron-weighted band structure calculation ...        '
    Write (*, '(a)') '================================================================'
    Write (*, '(a,i0,a)') '             Temperature: ', int(temperature), 'K'
    Write (*, '(a,i0)') '  Number of phonon bands: ', nbands
    Write (*, '(a)')

! Generate q-point list
    Call load_qpoints()

! Calculate spectra
    Write (*, '(a)') 'Start to compute phonon spectra ...'
    Call phoneigen()
    Write (*, '(a)') 'Phonon spectra calculation finished.'

! Initialize temperature and rmsd calculation 
    Call rmsdcalc(temperature)
    Call sqw_calc()
    Call write_sqw_intensity(nqtot, ne_bins, e_min, e_max, sqwsum, qdist)
    Write (*, '(a)')
  End Subroutine run_sqw_crystal

! Powder S(|Q|, E) driver
  Subroutine run_sqw_powder()
    Use variables, Only: temperature, nbands, e_min, e_max, ne_bins, sqwsum, &
                          q_min, q_max, nq_bins, npts_sphere, qdist, sampling
    Use output, Only: write_sqw_powder
    Use constants, Only: tpi, thz2mev, eps1, eps3, eps5, pi
    Use spectra, Only: dmsolver
    Use variables, Only: e_smearing, q_smearing, armsd
    Implicit None

    Integer (Kind=4) :: i_bin, i_dir, jj
    Real (Kind=8) :: q_mag, u, v, theta, phi
    Real (Kind=8) :: q_dir(3)
    Real (Kind=8) :: ee(ne_bins), de, sig
    Real (Kind=8) :: sqwtemp(nbands)

! Allocate memory for Q-points batch (one shell)
    Real (Kind=8), Allocatable :: q_shell(:, :) ! (3, npts_sphere)
    Real (Kind=8), Allocatable :: omega_shell(:, :) ! (npts_sphere, nbands)
    Complex (Kind=8), Allocatable :: eigenvec_shell(:, :, :) ! (npts_sphere, nbands, nbands)

    Write (*, '(a)') '================================================================'
    Write (*, '(a)') 'Starting powder neutron scattering calculation ...              '
    Write (*, '(a)') '================================================================'
    Write (*, '(a,i0,a)') '             Temperature: ', int(temperature), 'K'
    Write (*, '(a,i0)') '  Number of phonon bands: ', nbands
    Write (*, '(a,f0.2,a,f0.2)') '                 Q range: ', q_min, ' ~ ', q_max
    Write (*, '(a,i0)') '        Number of Q bins: ', nq_bins
    Write (*, '(a,i0)') '      Directions per bin: ', npts_sphere
    Write (*, '(a,a)') '         Sampling method: ', trim(sampling)

! RMSD calculation (same as single crystal) 
    Call rmsdcalc(temperature)

! Initialize results
    If (allocated(sqwsum)) Deallocate (sqwsum)
    Allocate (sqwsum(ne_bins,nq_bins))
    sqwsum = 0.D0

    If (allocated(qdist)) Deallocate (qdist)
    Allocate (qdist(nq_bins))

    Allocate (q_shell(3,npts_sphere))
    Allocate (omega_shell(npts_sphere,nbands))
    Allocate (eigenvec_shell(npts_sphere,nbands,nbands))

    If (ne_bins>1) Then
      ee = (/ (e_min+(e_max-e_min)*dble(jj-1)/dble(ne_bins-1),jj=1,ne_bins) /)
      de = (e_max-e_min)/dble(ne_bins-1)
    Else
      ee = e_min
      de = 0.D0
    End If

    Write (*, '(a)') 'Start to compute powder spectra ...'

! Loop over Q magnitude bins
    Do i_bin = 1, nq_bins
      If (nq_bins>1) Then
        q_mag = q_min + (q_max-q_min)*dble(i_bin-1)/dble(nq_bins-1)
      Else
        q_mag = q_min
      End If
      qdist(i_bin) = q_mag

      If (sampling(1:6)=='golden' .Or. sampling(1:6)=='GOLDEN' .Or. sampling(1:6)=='Golden') Then
        Do i_dir = 1, npts_sphere
          u = dble(i_dir-1)/dble(npts_sphere)
          v = dble(i_dir-1)/((1.D0+sqrt(5.D0))/2.D0)
          u = u + 1.D0/(2.D0*dble(npts_sphere))
          If (u>=1.D0) u = u - 1.D0
          v = v - floor(v)
          phi = 2.D0*pi*v
          theta = acos(2.D0*u-1.D0)
          q_dir(1) = cos(phi)*sin(theta)
          q_dir(2) = sin(phi)*sin(theta)
          q_dir(3) = cos(theta)
          q_shell(:, i_dir) = q_mag*q_dir
        End Do
      Else
        Do i_dir = 1, npts_sphere
          Call random_number(u)
          Call random_number(v)
          theta = 2.D0*pi*u
          phi = acos(2.D0*v-1.D0)
          q_dir(1) = sin(phi)*cos(theta)
          q_dir(2) = sin(phi)*sin(theta)
          q_dir(3) = cos(phi)
          q_shell(:, i_dir) = q_mag*q_dir
        End Do
      End If

      Call dmsolver(q_shell, omega_shell, eigenvec_shell, verbose=.False.)

! Post-process frequencies (convert to meV)
      omega_shell = omega_shell/tpi*thz2mev
      Where (omega_shell<0.D0) omega_shell = 0.D0
      Where (omega_shell<eps3) omega_shell = omega_shell + eps3

! Calculate S(Q,E) contribution
      Do i_dir = 1, npts_sphere
        Call sqw_givenq(q_shell(:,i_dir), omega_shell(i_dir,:), armsd, eigenvec_shell(i_dir,:,:), sqwtemp, temperature)

! Accumulate into energy bins
        Do jj = 1, nbands
          sig = gaussian_sigma_poly4(omega_shell(i_dir,jj), e_smearing, de)
          Call add_gaussian_to_grid(sqwsum(:,i_bin), ee, omega_shell(i_dir,jj), sig, sqwtemp(jj))
        End Do
      End Do

! Normalize by number of directions
      sqwsum(:, i_bin) = sqwsum(:, i_bin)/dble(npts_sphere)

      If (mod(i_bin,10)==0) Then
        Write (*, '(a,i4,a)') '  Progress:', int(i_bin*100./nq_bins), '%'
      End If
    End Do

! Apply Q-smearing if requested
    If (any(abs(q_smearing)>1.D-6)) Then
      Call apply_q_smearing(sqwsum, nq_bins, q_min, q_max, q_smearing, ne_bins)
    End If

    Where (sqwsum<eps5) sqwsum = sqwsum + eps5

    Deallocate (q_shell, omega_shell, eigenvec_shell)

! Write output
    Call write_sqw_powder(nq_bins, ne_bins, e_min, e_max, sqwsum, qdist)

    Write (*, '(a)') 'Powder neutron scattering calculation finished.'
    Write (*, '(a)')
  End Subroutine run_sqw_powder

  Subroutine apply_q_smearing(sqwsum, nq_bins, q_min, q_max, q_smearing, ne_bins)
    Use func, Only: gauss
    Implicit None
    Integer (Kind=4), Intent (In) :: nq_bins, ne_bins
    Real (Kind=8), Intent (In) :: q_min, q_max, q_smearing(:)
    Real (Kind=8), Intent (Inout) :: sqwsum(ne_bins, nq_bins)

    Real (Kind=8), Allocatable :: new_sqwsum(:, :)
    Real (Kind=8) :: dq, qgrid(nq_bins), q_source, sig, weight
    Integer (Kind=4) :: i, j, k_min, k_max, idx

    If (nq_bins<=1) Return

    Allocate (new_sqwsum(ne_bins,nq_bins))
    new_sqwsum = 0.D0
    dq = (q_max-q_min)/dble(nq_bins-1)

    qgrid = (/ (q_min+(q_max-q_min)*dble(idx-1)/dble(nq_bins-1),idx=1,nq_bins) /)

    Do j = 1, nq_bins ! source
      q_source = qgrid(j)
      sig = gaussian_sigma_poly4(q_source, q_smearing, dq)

      k_min = max(1, int(floor((q_source-5.D0*sig-q_min)/dq))+1)
      k_max = min(nq_bins, int(ceiling((q_source+5.D0*sig-q_min)/dq))+1)

      Do i = k_min, k_max ! target
        weight = gauss(qgrid(i), q_source, sig)*dq
        new_sqwsum(:, i) = new_sqwsum(:, i) + sqwsum(:, j)*weight
      End Do
    End Do

    sqwsum = new_sqwsum
    Deallocate (new_sqwsum)
  End Subroutine apply_q_smearing
End Module sqw_phonon
