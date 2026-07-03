.SUFFIXES: .f90

#-----------------------------------------------
# Makefile for the program 'nephonon'.
# Please modify the variables properly.
# We recommend to use Intel fortran compiler.
#-----------------------------------------------

CXX = g++
CXXFLAGS = -O3 -std=c++14 -Inepcpu

FC = ifort
FFLAGS = -O3 -march=native -funroll-loops
## FFLAGS = -O3 -Wall -march=native -ffast-math -funroll-loops

# Linking flags for LAPACK/BLAS
# Option 1: Use Intel MKL (recommended if available)
# LDFLAGS = -qmkl

# Option 2: Use system LAPACK/BLAS (if MKL is not available, uncomment below and comment above)
LDFLAGS = -L. -llapack -lblas

# Option 3: Specify library path explicitly
# LDFLAGS = -L/usr/lib64 -llapack -lblas
# LDFLAGS = -L. -llapack -lblas -flto -O3

LAPACK = 
LIBS = $(LAPACK)

#-----------------------------------------------
# General rules 
#-----------------------------------------------

# Source files for nephonon calculation
PHONON_SRC = constants.f90 variables.f90 func.f90 output.f90 spectra.f90 symmetrization.f90 readinp.f90 dos_calc.f90 band_calc.f90 isosurface_calc.f90 sqw_util.f90 sqw_phonon.f90 calc_fc2.f90 nephonon.f90

PHONON_OBJS = constants.o variables.o func.o output.o spectra.o symmetrization.o readinp.o dos_calc.o band_calc.o isosurface_calc.o sqw_util.o sqw_phonon.o calc_fc2.o nephonon.o

# C++ Objects
CPP_OBJS = nep.o ewald_nep.o neighbor_nep.o nep_wrapper.o

default: nephonon

all: nephonon

nephonon: ${CPP_OBJS} ${PHONON_OBJS}
	${FC} ${LDFLAGS} -o $@ ${PHONON_OBJS} ${CPP_OBJS} ${LIBS} -lstdc++

# Dependencies - explicit rules to ensure correct compilation order
constants.o constants.mod: constants.f90
	$(FC) $(FFLAGS) -c -o constants.o constants.f90

variables.o variables.mod: variables.f90 constants.mod
	$(FC) $(FFLAGS) -c -o variables.o variables.f90

func.o func.mod: func.f90 constants.mod
	$(FC) $(FFLAGS) -c -o func.o func.f90

output.o output.mod: output.f90 constants.mod
	$(FC) $(FFLAGS) -c -o output.o output.f90

spectra.o spectra.mod: spectra.f90 variables.mod constants.mod func.mod
	$(FC) $(FFLAGS) -c -o spectra.o spectra.f90

symmetrization.o symmetrization.mod: symmetrization.f90 variables.mod
	$(FC) $(FFLAGS) -c -o symmetrization.o symmetrization.f90

readinp.o readinp.mod: readinp.f90 variables.mod constants.mod func.mod symmetrization.mod
	$(FC) $(FFLAGS) -c -o readinp.o readinp.f90

dos_calc.o dos_calc.mod: dos_calc.f90 variables.mod spectra.mod constants.mod output.mod
	$(FC) $(FFLAGS) -c -o dos_calc.o dos_calc.f90

band_calc.o band_calc.mod: band_calc.f90 variables.mod spectra.mod constants.mod output.mod
	$(FC) $(FFLAGS) -c -o band_calc.o band_calc.f90

isosurface_calc.o isosurface_calc.mod: isosurface_calc.f90 variables.mod spectra.mod constants.mod output.mod
	$(FC) $(FFLAGS) -c -o isosurface_calc.o isosurface_calc.f90

sqw_util.o sqw_util.mod: sqw_util.f90 variables.mod spectra.mod constants.mod func.mod
	$(FC) $(FFLAGS) -c -o sqw_util.o sqw_util.f90

sqw_phonon.o sqw_phonon.mod: sqw_phonon.f90 sqw_util.mod variables.mod spectra.mod constants.mod func.mod output.mod
	$(FC) $(FFLAGS) -c -o sqw_phonon.o sqw_phonon.f90

calc_fc2.o calc_fc2_mod.mod: calc_fc2.f90 variables.mod
	$(FC) $(FFLAGS) -c -o calc_fc2.o calc_fc2.f90

nephonon.o: nephonon.f90 readinp.mod variables.mod constants.mod spectra.mod dos_calc.mod band_calc.mod isosurface_calc.mod sqw_phonon.mod calc_fc2_mod.mod
	$(FC) $(FFLAGS) -c -o nephonon.o nephonon.f90

# C++ Compilation Rules
nep.o: nepcpu/nep.cpp
	$(CXX) $(CXXFLAGS) -c nepcpu/nep.cpp -o nep.o

ewald_nep.o: nepcpu/ewald_nep.cpp
	$(CXX) $(CXXFLAGS) -c nepcpu/ewald_nep.cpp -o ewald_nep.o

neighbor_nep.o: nepcpu/neighbor_nep.cpp
	$(CXX) $(CXXFLAGS) -c nepcpu/neighbor_nep.cpp -o neighbor_nep.o

nep_wrapper.o: nep_wrapper.cpp
	$(CXX) $(CXXFLAGS) -c nep_wrapper.cpp -o nep_wrapper.o

# Default rule for files without explicit dependencies
%.o %.mod: %.f90
	$(FC) $(FFLAGS) -c -o $*.o $<

clean:
	rm -f *.o *.mod

.PHONY: clean
