# Makefile for fifofum
#
# Edit SRCROOT to point to the source directory.
# Then create a separate work directory, and copy this Makefile there.
#
# 'make fifo_test' creates an executable that can be run later.
#
# 'make test_f_server' creates the executable, runs it, and pipes the output to the web server.
#
# 'make test_with_background' does the same as above, but adding a background image.
#
# 'make fifo_c_test' tests only the C functions.
# 
# For debugging, use 'make CPPDEFS=-DDEBUG_PNG ...'
#

SRCROOT = ./src

CPPDEFS = # -DTEST_STDOUT -DTEST_GRAPHTERM -DDEBUG_FIFO

CPPFLAGS = # -I...

FFLAGS = $(CPPFLAGS) -i4 -r8
CFLAGS = 

CC = icc
FC = ifort
LD = ifort

LDFLAGS = -lpng

.DEFAULT:
	-touch $@

all: fifo_test

fifo_c.o: $(SRCROOT)/fifo_c.c
	$(CC) $(CPPDEFS) $(CPPFLAGS) $(CFLAGS) -c $(SRCROOT)/fifo_c.c

fifo_f.o: $(SRCROOT)/fifo_f.f90 fifo_c.o
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -c $(SRCROOT)/fifo_f.f90

./fifo_c.c: $(SRCROOT)/fifo_c.c
	cp $(SRCROOT)/fifo_c.c .

./fifo_f.f90: $(SRCROOT)/fifo_f.f90
	cp $(SRCROOT)/fifo_f.f90 .

./fifo_test.F90: $(SRCROOT)/fifo_test.F90
	cp $(SRCROOT)/fifo_test.F90 .

SRC = $(SRCROOT)/fifo_c.c $(SRCROOT)/fifo_f.f90 $(SRCROOT)/fifo_test.F90

OBJ = fifo_c.o fifo_f.o

OUTFILES = testin.fifo testout.fifo testpng.png testpng.b64

clean: neat
	-rm -f .cppdefs $(OBJ) fifo_f.mod fifo_test fifo_test_stdout fifo_c_test
neat:
	-rm -f $(TMPFILES) $(OUTFILES)
localize: $(SRC) $(SRCROOT)/fifofum.py
	cp $(SRC) $(SRCROOT)/fifofum.py .

fifo_c_test: $(SRCROOT)/fifo_c.c
	$(CC) -DTEST_MAIN $(CPPDEFS) $(CPPFLAGS) $(CFLAGS) -o fifo_c_test $(SRCROOT)/fifo_c.c $(LDFLAGS)

fifo_test: $(OBJ) $(SRCROOT)/fifo_test.F90
	$(FC) $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -o fifo_test $(SRCROOT)/fifo_test.F90 $(OBJ) $(LDFLAGS)

fifo_test_stdout: $(OBJ) $(SRCROOT)/fifo_test.F90
	$(FC) -DTEST_STDOUT $(CPPDEFS) $(CPPFLAGS) $(FFLAGS) -o fifo_test_stdout $(SRCROOT)/fifo_test.F90 $(OBJ) $(LDFLAGS)

test_f_server: fifo_test_stdout
	./fifo_test_stdout | python $(SRCROOT)/fifofum.py --input=testin.fifo _

test_with_background: fifo_test_stdout
	./fifo_test_stdout | python $(SRCROOT)/fifofum.py --background=http://eoimages.gsfc.nasa.gov/images/imagerecords/74000/74092/world.200407.3x5400x2700.jpg --input=testin.fifo  _

