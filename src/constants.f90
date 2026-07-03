!=============================================================================
! Physical constants and unit conversion factors module
!
! This module contains:
!   - Mathematical constants (pi)
!   - Physical constants (Boltzmann constant, Planck constant)
!   - Unit conversion factors for phonon calculations
!   - Periodic table element symbols and atomic masses (Z=1..96)
!   - Neutron scattering lengths and cross sections (reference values)
!=============================================================================

Module constants

  Implicit None

!===========================================================================
! Mathematical constants
!===========================================================================
  Real (Kind=8), Parameter :: pi = acos(-1.D0) ! Pi (calculated at compile time)
  Real (Kind=8), Parameter :: tpi = 2.D0*pi ! 2*Pi
  Complex (Kind=8), Parameter :: iunit = (0.0D0, 1.0D0) ! Imaginary unit

!===========================================================================
! Fundamental physical constants
!===========================================================================
  Real (Kind=8), Parameter :: kbj = 1.380648813E-23  ! Boltzmann constant [J/K]
  Real (Kind=8), Parameter :: hbar = 1.054571800E-34 ! Reduced Planck constant [J*s]
  Real (Kind=8), Parameter :: barn = 1E-24  !cm^2
  Real (Kind=8), Parameter :: afj = 6.02E23 !avogadro's number

!===========================================================================
! Unit conversion factors for phonon calculations
!===========================================================================
! Conversion from force-constant units to frequency squared
  Real (Kind=8), Parameter :: dm2thz = 9648.53336213D0 ! eV/(Angstrom^2*amu) -> THz^2

! Conversion factor used in non-analytic correction (LO-TO splitting)
  Real (Kind=8), Parameter :: thz2amua3 = 1745913.10995753D0 ! THz^2*amu*Angstrom^3

! Conversion from frequency to energy
  Real (Kind=8), Parameter :: thz2mev = 4.13566733D0 ! THz -> meV (angular frequency)

  Real (Kind=8), Parameter :: amu = 1.66053906660D-27 ! Atomic mass unit [kg]
  Real (Kind=8), Parameter :: a2m = 1.0D-10 ! Angstrom to meter conversion

! Time unit conversion
  Real (Kind=8), Parameter :: ps2s = 1.0E-12 ! Picoseconds to seconds

!===========================================================================
! Numerical precision thresholds
! Used for comparing floating-point numbers to zero
!===========================================================================
  Real (Kind=8), Parameter :: eps1 = 1.0E-1 ! Threshold for "zero" (10%)
  Real (Kind=8), Parameter :: eps3 = 1.0E-3 ! Threshold for "zero" (0.1%)
  Real (Kind=8), Parameter :: eps4 = 1.0E-4 ! Threshold for "zero" (0.01%)
  Real (Kind=8), Parameter :: eps5 = 1.0E-5 ! Threshold for "zero" (0.001%)

! List of elements, ordered by atomic number.
  Character (Len=3), Parameter :: periodic_table(96) = [ Character(Len=3) :: "H","He" & !H->He
    , "Li","Be","B","C","N","O","F","Ne" & !Li->Ne
    , "Na","Mg","Al","Si","P","S","Cl","Ar" & !Na->Ar
    , "K","Ca","Sc","Ti","V","Cr","Mn","Fe","Co" & !K->Co
    , "Ni","Cu","Zn","Ga","Ge","As","Se","Br","Kr" & !Ni->Kr
    , "Rb","Sr","Y","Zr","Nb","Mo","Tc","Ru","Rh" & !Ru->Rh
    , "Pd","Ag","Cd","In","Sn","Sb","Te","I","Xe" & !Pd->Xe
    , "Cs","Ba","La","Ce","Pr","Nd","Pm","Sm","Eu" & !Cs->Eu
    , "Gd","Tb","Dy","Ho","Er","Tm","Yb","Lu" & !Gd->Lu
    , "Hf","Ta","W","Re","Os","Ir","Pt","Au","Hg","Tl","Pb","Bi","Po","At","Rn" & !Hf->Rn
    , "Fr","Ra","Ac","Th","Pa","U","Np","Pu","Am","Cm"] !Fr->Cm

! Atomic masses (amu), ordered by atomic number.
  Real (Kind=8), Parameter :: atomic_masses(96) = [ Real(Kind=8) :: 1.00794, 4.002602 & !H->He
    , 6.941, 9.012182, 10.811, 12.0107, 14.0067, 15.9994, 18.9984032, 20.1797 & !Li->Ne
    , 22.98976928, 24.3050, 26.9815386, 28.0855, 30.973762, 32.065, 35.453, 39.948 & !Na->Ar
    , 39.0983, 40.078, 44.955912, 47.867, 50.9415, 51.9961, 54.938045, 55.845, 58.933195 & !K->Co
    , 58.6934, 63.546, 65.38, 69.723, 72.64, 74.92160, 78.96, 79.904, 83.798 & !Ni->Kr
    , 85.4678, 87.62, 88.90585, 91.224, 92.90638, 95.96, 98, 101.07, 102.90550 & !Ru->Rh
    , 106.42, 107.8682, 112.411, 114.818, 118.710, 121.760, 127.60, 126.90447, 131.293 & !Pd->Xe
    , 132.9054519, 137.327, 138.90547, 140.116, 140.90765, 144.242, 145, 150.36, 151.964 & !Cs->Eu
    , 157.25, 158.92535, 162.500, 164.93032, 167.259, 168.93421, 173.054, 174.9668 & !Gd->Lu
    , 178.49, 180.94788, 183.84, 186.207, 190.23, 192.217, 195.084, 196.966569, 200.59, 204.3833, 207.2, 208.98040, 209, 210, 222 & !Hf->Rn
    , 223, 226, 227, 232.03806, 231.0358, 238.02891, 237, 244, 243, 247 ] !Fr->Cm

! Data source: https://www.ncnr.nist.gov/resources/n-lengths/
! Neutron coherent scattering lengths (fm), ordered by Z.
  Real (Kind=8), Parameter :: scatt_length(96) = [ Real(Kind=8) :: -3.7409, 3.0985 & !H->He
    , -1.930, 7.790, 5.30, 6.6472, 9.360, 5.8037, 5.654, 4.566 & !Li->Ne
    , 3.630, 5.375, 3.449, 4.15071, 5.130, 2.8470, 9.5792, 1.909 & !Na->Ar
    , 3.670, 4.700, 12.10, -3.370, -0.443, 3.635, -3.750, 9.450, 2.490 & !K->Co
    , 10.30, 7.718, 5.680, 7.2880, 8.185, 6.580, 7.970, 6.790, 7.810 & !Ni->Kr
    , 7.080, 7.020, 7.750, 7.160, 7.0540, 6.715, 6.80, 7.020, 5.90, 5.91, 5.922, 4.83, 4.065, 6.2239, 5.570, 5.680, 5.280, 4.69 & !Rb->Xe
    , 5.420, 5.070, 8.24, 4.840, 4.44, 7.87, 12.6, 0.00, 5.30, 9.50, 7.340, 16.90, 8.440, 7.790, 7.070, 12.410, 7.210 & !Cs->Lu
    , 7.77, 6.91, 4.755, 9.20, 10.70, 10.60, 9.600, 7.90, 12.60, 8.776, 9.4024, 8.5242, 0.0, 0.0, 0.0 & !Hf->Rn
    , 0.0, 10.0, 0.0, 10.310, 9.10, 8.417, 10.55, 7.70, 8.30, 9.50 ] !Fr->Cm

! Total bound scattering cross sections (barn), ordered by Z.
  Real (Kind=8), Parameter :: scatt_total(96) = [ Real(Kind=8) :: 82.02, 1.2065 & !H->He
    , 1.370, 7.630, 5.24, 5.5510, 11.51, 4.232, 4.018, 2.628 & !Li->Ne
    , 3.28, 3.71, 1.503, 2.167, 3.312, 1.026, 16.8, 0.683 & !Na->Ar
    , 1.96, 2.830, 23.5, 4.350, 5.10, 3.490, 2.150, 11.62, 5.60 & !K->Co
    , 18.50, 8.030, 4.131, 6.830, 8.60, 5.500, 8.30, 5.90, 7.685 & !Ni->Kr
    , 6.8, 6.25, 7.70, 6.46, 6.255, 5.71, 6.3, 6.60, 4.60, 4.48, 4.990, 6.50, 2.62, 4.892, 3.90, 4.32, 3.81, 4.344 & !Rb->Xe
    , 3.90, 3.38, 9.66, 2.94, 2.66, 16.6, 21.3, 39.4, 9.2, 180.0, 6.84, 90.3, 8.42, 8.70, 6.38, 23.40, 7.2 & !Cs->Lu
    , 10.2, 6.01, 4.60, 11.50, 14.7, 14.0, 11.71, 7.75, 26.80, 9.89, 11.118, 9.156, 0.0, 0.0, 0.0 & !Hf->Rn
    , 0.0, 13.0, 0.0, 13.36, 10.5, 8.908, 14.5, 7.7, 9.0, 11.3 ] !Fr->Cm

! Absorption cross sections (barn) for 2200 m/s neutrons, ordered by Z.
  Real (Kind=8), Parameter :: scatt_absorp(96) = [ Real(Kind=8) :: 0.3326, 0.00747 & !H->He
    , 70.5, 0.0076, 767, 0.00350, 1.900, 0.000190, 0.0096, 0.039 & !Li->Ne
    , 0.530, 0.0630, 0.2310, 0.1710, 0.172, 0.530, 33.5, 0.675 & !Na->Ar
    , 2.10, 0.430, 27.5, 6.09, 5.08, 3.05, 13.30, 2.560, 37.18 & !K->Co
    , 4.49, 3.780, 1.110, 2.750, 2.20, 4.50, 11.70, 6.90, 25.0 & !Ni-Kr
    , 0.380, 1.28, 1.280, 0.1850, 1.15, 2.48, 20.0, 2.56, 144.8, 6.9, 63.3, 2520, 193.8, 0.626, 4.91, 4.70, 6.15, 23.9 & !Rb->Xe
    , 29.0, 1.10, 8.970, 0.63, 11.50, 50.5, 168.4, 5922, 4530, 49700, 23.4, 994, 64.7, 159, 100.0, 34.8, 74.0 & !Cs->Lu
    , 104.1, 20.6, 18.30, 89.7, 16, 425.0, 10.30, 98.65, 372, 3.43, 0.1710, 0.0338, 0.0, 0.0, 0.0 & !Hf->Rn
    , 0.0, 12.8, 0.0, 7.37, 200.6, 7.570, 175.9, 1017.3, 75.3, 16.2 ] !Fr->Cm
End Module constants
