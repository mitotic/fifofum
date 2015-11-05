# Using fifofum with GFDL/FMS dynamical core

`fifofum` has been tested with the shallow water atmospheric dynamical core from the
[Flexible Modeling System](http://www.gfdl.noaa.gov/fms) developed by
the NOAA Geophysical Fluid Dynamical Laboratory. The following code
modifications are required to implement graphics in the B-grid shallow
water dry dynamical core.

- First, modify the main driver `src/atmos_bgrid/driver/shallow/atmosphere.f90`

 - Include the Fortran module

```FORTRAN
    use fifo_f
```

- Declare global variables

```FORTRAN
    integer :: fifo_pipe_num
    character(len=*), parameter :: fifo_file = "fms_pipe.fifo"
```

- Set up pipe in the initialization routine (`atmosphere_init`)

```FORTRAN
    if ( mpp_pe() == mpp_root_pe() ) then
        ! Initialize plot pipe
        fifo_pipe_num = allocate_file_pipe(fifo_file)
    end if
```

- Display image with caption in the time-stepping routine (`atmosphere`)

```fortran
    character(len=81) :: fifo_line
    real :: data_values(144,90)
    integer fifo_sec, fifo_status

    if ( mpp_pe() == mpp_root_pe() ) then
        call get_time(Time, fifo_sec)
        write(fifo_line, '(a,g)')  "seconds=", fifo_sec    ! Plot caption string displaying model time
    
        data_values(:,:) = Var%ps(:,:)                     ! Copy model surface pressure values
        where(data_values < 32000.) data_values = 0.0      ! Mask out low pressure values as undefined
    
        ! Plot 2-D array to fifo_pipe, using caption string and default Viridis color map with opacity of 0.9 for data values
        ! Use color index 15 for undefined (zero) values and make it transparent
        ! (For more info, see comments for the subroutine fifo_plot2d in fifo_f.f90)
        fifo_status = fifo_plot2d(fifo_pipe_num, data_values, trim(fifo_line), colormap_code=1, opacity=0.9, &
                                                undef_value=0.0, undef_color=15, transp_color=15)
    end if
```

- Include `fifo_f.f90` and `fifo_c.c` in your source files
   when compiling. In the linking options, add the following:

```sh
  LDFLAGS = ... fifo_f.o fifo_c.o -lpng
```
	
- Login to remote computer using port forwarding:

```sh
  ssh -L 8008:localhost:8008 user@remote
```

- Run dynamical core in the background and start web server (or use two
  terminal windows, one for each command). The Fortran program creates
  a file-like FIFO object named `fms_pipe.fifo` in the run
  directory. The Python web server reads from this "file" and streams the
  output images, overlaid on a background image.

```sh
  mpirun -np 1 ./fms.x &

  # Use NASA Blue Marble image as background
  python fifofum.py --background=http://eoimages.gsfc.nasa.gov/images/imagerecords/74000/74092/world.200407.3x5400x2700.jpg fms_pipe.fifo
```

- Open URL <http://localhost:8008> in local web server

## Sample live output from FMS

The following image shows animation of surface pressure during a
test run of the shallow water model.

![shallow water](https://raw.githubusercontent.com/mitotic/fifofum/master/doc/images/fms_live.gif)
