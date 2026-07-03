!=============================================================================
! Utility functions module
!
! This module provides commonly used mathematical functions:
!   - 3D cross product
!   - Integer division with remainder
!   - Complex exponential (optimized)
!=============================================================================

Module func
  Use constants, Only: pi, tpi, ps2s, hbar, kbj, thz2mev
  Implicit None
  Private
  Public :: fbe, fbemev, gauss, gaussian_sigma_poly4, cross_prod, divmod, phexp

Contains

!===========================================================================
! Bose-Einstein occupation factor
!
! Computes n(omega, T) = 1 / (exp(hbar*omega/kB/T) - 1).
!
! Inputs:
!   e - Angular frequency (1/ps).
!   t - Temperature (K).
! Output:
!   fbe - Occupation factor.
!===========================================================================
  Function fbe(e, t)
    Implicit None
    Real (Kind=8), Intent (In) :: e, t
    Real (Kind=8) :: fbe
    Real (Kind=8) :: x

    x = e/ps2s
    fbe = 1.D0/(exp(hbar*x/kbj/t)-1.D0)
  End Function fbe

!===========================================================================
! Bose-Einstein occupation factor (energy input)
!
! Same as fbe(), but takes energy in meV and internally converts to
! angular frequency.
!
! Inputs:
!   e - Energy (meV).
!   t - Temperature (K).
! Output:
!   fbemev - Occupation factor.
!===========================================================================
  Function fbemev(e, t)
    Implicit None
    Real (Kind=8), Intent (In) :: e, t
    Real (Kind=8) :: fbemev
    Real (Kind=8) :: x

    x = e/thz2mev*tpi/ps2s
    fbemev = 1.D0/(exp(hbar*x/kbj/t)-1.D0)
  End Function fbemev

!===========================================================================
! Normalized Gaussian
!
! Returns a normalized Gaussian value:
!   g(x) = 1/(sqrt(2*pi)*sigma) * exp(-(x-center)^2/(2*sigma^2)).
!
! Inputs:
!   thise   - Evaluation point.
!   ecenter - Center of the Gaussian.
!   sig     - Standard deviation (sigma). Must be > 0.
! Output:
!   gauss - Gaussian value at thise.
!===========================================================================
  Function gauss(thise, ecenter, sig)
    Implicit None
    Real (Kind=8), Intent (In) :: thise, ecenter, sig
    Real (Kind=8) :: gauss
    Real (Kind=8) :: pree

    pree = 1.D0/sqrt(tpi)/sig
    gauss = pree*exp(-(thise-ecenter)**2/2.D0/sig**2)
  End Function gauss

!===========================================================================
! Convert polynomial FWHM model to sigma
!
! Uses a 4th-order polynomial in the non-negative coordinate to compute a
! full-width-at-half-maximum (FWHM), then converts to sigma:
!   sigma = FWHM / (2*sqrt(2*ln(2))).
!
! Inputs:
!   center - Coordinate at which to evaluate the resolution model.
!   coeffs - Polynomial coefficients (size 5): c0..c4.
!   dmin   - Minimum grid spacing used to enforce a positive lower bound.
! Output:
!   sigma - Standard deviation (sigma).
!===========================================================================
  Function gaussian_sigma_poly4(center, coeffs, dmin) Result (sigma)
    Implicit None
    Real (Kind=8), Intent (In) :: center, coeffs(:), dmin
    Real (Kind=8) :: x, sigma
    Real (Kind=8) :: fwhm, fwhm_min
    Real (Kind=8), Parameter :: sigma_to_fwhm = 2.D0*sqrt(2.D0*log(2.D0))

    x = max(center, 0.D0)
    fwhm = coeffs(1) + coeffs(2)*x + coeffs(3)*(x**2) + coeffs(4)*(x**3) + coeffs(5)*(x**4)
    fwhm_min = max(abs(dmin), 1.D-12)
    If (fwhm<fwhm_min) fwhm = fwhm_min
    sigma = fwhm/sigma_to_fwhm
  End Function gaussian_sigma_poly4

!===========================================================================
! Compute 3D cross product: res = a × b
!
! This subroutine calculates the cross product of two 3D vectors
! using a cyclic-permutation indexing scheme.
!
! Inputs:
!   a(3) - First vector
!   b(3) - Second vector
! Output:
!   res(3) - Cross product result (a × b)
!
! Formula: res_i = a_j * b_k - a_k * b_j
!          where (i,j,k) is a cyclic permutation of (1,2,3)
!===========================================================================
  Subroutine cross_prod(a, b, res)
    Real (Kind=8), Intent (In) :: a(3), b(3)
    Real (Kind=8), Intent (Out) :: res(3)
    Integer (Kind=4) :: i, j, k

! Use cyclic permutation: (1,2,3) -> (2,3,1) -> (3,1,2)
    Do i = 1, 3
      j = mod(i, 3) + 1 ! Next index: 1->2, 2->3, 3->1
      k = mod(j, 3) + 1 ! Next after j: 2->3, 3->1, 1->2
      res(i) = a(j)*b(k) - a(k)*b(j)
    End Do
  End Subroutine cross_prod

!===========================================================================
! Compute quotient and remainder of integer division
!
! This subroutine performs integer division and returns both the quotient
! and remainder, similar to Python's divmod() function.
!
! Inputs:
!   a - Dividend
!   b - Divisor
! Outputs:
!   q - Quotient (a / b, integer division)
!   r - Remainder (a mod b)
!
! Note: a = q * b + r
!===========================================================================
  Subroutine divmod(a, b, q, r)
    Implicit None
    Integer (Kind=4), Intent (In) :: a, b
    Integer (Kind=4), Intent (Out) :: q, r

    q = a/b ! Integer division (truncates toward zero)
    r = mod(a, b) ! Remainder
  End Subroutine divmod

!===========================================================================
! Compute complex exponential: exp(i*x) = cos(x) + i*sin(x)
!
! This function is optimized for the specific case of exp(i*x),
! which is faster than the general complex exponential function.
! Used extensively in Fourier transforms for phonon calculations.
!
! Input:
!   x - Real argument (in radians)
! Output:
!   phexp - Complex result: cos(x) + i*sin(x)
!
! This is equivalent to exp(i*x) but computed directly using
! trigonometric functions for better performance.
!===========================================================================
  Function phexp(x)
    Implicit None
    Real (Kind=8), Intent (In) :: x
    Complex (Kind=8) :: phexp

    phexp = cmplx(cos(x), sin(x), kind=8)
  End Function phexp
End Module func
