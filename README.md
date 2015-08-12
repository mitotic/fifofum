# fifofum: A lightweight graphics library for displaying 2-d output from running Fortran programs using FIFO pipes

Typically, the output from a computer program like a weather or climate model is saved to files and visualized after the program completes
a stage of execution. When developing and debugging such a computer program, it would be useful to have a "real time" display of the graphical output
to track the evolution of numerical instabilities etc. An interactive
graphics display would also be useful for pedagogical purposes.

One could, for example, make calls to a graphics library from the
running program and use X windows to display images. Unfortunately
the few Fortran-callable graphics libraries tend to be
complex. These libraries often introduce  many additional
dependencies, making the program less portable and difficult to install.
Also, interactive graphical displays typically require "event loops" which can unnecessarily complicate program logic.

`fifofum` is a very simple graphics library that displays a
2-dimensional data matrix as a pixel image, optionally overlaid on another
background image. It transmits output using Unix named pipes (which are also known as FIFOs, because data is transmitted in a
First In, First Out fashion).  Linking to the `fifofum` library enables running programs to continuously
write text and PNG image data to named pipes, which appear like files.
A different program reads from these named files and continuously displays the output, as needed.
(If no program is reading from the named pipe, the output is conveniently discarded.)

The basic FIFO pipe code is written in C (`fifo_c.c`), and a Fortran wrapper (`fifo_f.f90`) is provided. 
The package also includes a Python web server (`fifofum.py`) that reads data streams from multiple named pipes
and displays the images and text in a browser window. The display is continually updated as new data arrives.
(Other custom-written software can also be used to read and process the data from the named pipes.)

`fifofum` can also be used in conjunction with any other graphics library that
generates binary images (in PNG or other formats). The binary images
captured from the other libarary can be dumped to a named pipe stream
and then displayed in the browser.

## Usage example


Sample Fortran code snippet (see `src/fifo_test.F90`)

```FORTRAN
    real :: data_values(width, height)
    pipe_num = allocate_file_pipe("testout.fifo")
    do
	    ! ... compute data values
        status = fifo_plot2d(pipe_num, data_values, label="Data")
    end do
```
	
Compile, link, and run using `gcc/gfortran`

```sh
gcc -c fifo_c.c
gfortran -c -fdefault-real-8 fifo_f.f90
gfortran -o fifo_test -fdefault-real-8 fifo_test.F90 fifo_f.o fifo_c.o -lpng
./fifo_test &
```

Run web server to display output and capture input.

```sh
python fifofum.py --input=testin.fifo testout.fifo
```

Open link `http://localhost:8008` using a web browser to view the animated image and send text input.

If you are running the data-generating program and the web server on a remote computer via `ssh`, use the following
command to forward port `8008` for local browser access:

```sh
ssh -L 8008:localhost:8008 user@remote.computer
```

Try the command `make test_with_background` for a fancier animation.

For more information, see:

 - Test program `src/fifo_test.F90`

 - Comments at the top of `src/fifo_f.f90` and `src/fifofum.py`

 - Function `fifo_plot2d` in  ``src/fifo_f.f90``

 - `python fifofum.py --help`

- `Makefile`



*Notes:*

1. For Intel compilers, use `icc/ifort` and the `-r8` option instead of `-fdefault-real-8`.
 
2. On OS X, you may need to add options like `-I/opt/X11/include/libpng15 -L/opt/X11/lib` when compiling `fifo_c.c` (after installing X11)


## Dependencies


The dependencies are minimal:

 * the `libpng` library to create PNG output data

 * the Python Tornado module for the web server.

Library `libpng` is standard on most Unix systems. If necessary, use the `pip install tornado` command to install Tornado.


## Implementation notes

By default, line-oriented I/O is used for writing to and reading from named pipes.

Images are written to the named pipe using the Data URL format (`data:image/png;base64,...`), terminated by a new line.


