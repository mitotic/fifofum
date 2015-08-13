# Makefile for fifofum
#
# Edit SRCROOT to point to the source directory.
# Then create a separate work directory, and copy this Makefile there.
#
# 'make test_animate' creates an executable that can be run later.
#
# 'make test_animate_server' creates the executable, runs it, and pipes the output to the web server.
#
# 'make test_with_background' does the same as above, but adding a background image.
#
# 'make fifo_c_test' tests only the C functions.
# 
# For debugging, use 'make CPPDEFS=-DDEBUG_PNG ...'
#

SRCROOT = ../src

CPPDEFS = # -DTEST_STDOUT -DDEBUG_FIFO

CPPFLAGS = # -I...

FFLAGS = $(CPPFLAGS) -i4 -r8
CFLAGS = 

CC = icc
FC = ifort
LD = ifort

LDFLAGS = -lpng

.DEFAULT:
	-touch $@

all: test_animate test_file test_other fifo_c_test

fifo_c.o: $(SRCROOT)/fifo_c.c
	$(CC) $(CPPDEFS) $(CPPFLAGS) $(CFLAGS) -c $(SRCROOT)/fifo_c.c

fifo_f.o: $(SRCROOT)/fifo_f.f90 fifo_c.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -c $(SRCROOT)/fifo_f.f90

./fifo_c.c: $(SRCROOT)/fifo_c.c
	cp $(SRCROOT)/fifo_c.c .

./fifo_f.f90: $(SRCROOT)/fifo_f.f90
	cp $(SRCROOT)/fifo_f.f90 .

./test_animate.F90: test_animate.F90
	cp test_animate.F90 .

SRC = $(SRCROOT)/fifo_c.c $(SRCROOT)/fifo_f.f90

OBJ = fifo_c.o fifo_f.o

OUTFILES = testin.fifo testout.fifo testpng.png testpng.b64

clean: neat
	-rm -f .cppdefs $(OBJ) fifo_f.mod fifo_c_test test_animate test_animate_stdout test_graphterm test_file test_other
neat:
	-rm -f $(TMPFILES) $(OUTFILES)
localize: $(SRC) $(SRCROOT)/fifofum.py
	cp $(SRC) $(SRCROOT)/fifofum.py .

fifo_c_test: $(SRCROOT)/fifo_c.c
	$(CC) -DTEST_MAIN $(CPPDEFS) $(CPPFLAGS) $(CFLAGS) -o fifo_c_test $(SRCROOT)/fifo_c.c $(LDFLAGS)

test_file: $(OBJ) test_file.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -o test_file test_file.F90 $(OBJ) $(LDFLAGS)

test_graphterm: $(OBJ) test_graphterm.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -o test_graphterm test_graphterm.F90 $(OBJ) $(LDFLAGS)

test_other: $(OBJ) test_other.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -o test_other test_other.F90 $(OBJ) $(LDFLAGS)

test_animate: $(OBJ) test_animate.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -o test_animate test_animate.F90 $(OBJ) $(LDFLAGS)

test_animate_stdout: $(OBJ) test_animate.F90
	$(FC) -DTEST_STDOUT $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -o test_animate_stdout test_animate.F90 $(OBJ) $(LDFLAGS)

test_animate_server: test_animate_stdout
	./test_animate_stdout | python $(SRCROOT)/fifofum.py --input=testin.fifo _

test_with_background: test_animate_stdout
	./test_animate_stdout | python $(SRCROOT)/fifofum.py --background=http://eoimages.gsfc.nasa.gov/images/imagerecords/74000/74092/world.200407.3x5400x2700.jpg --input=testin.fifo  _

