program fifo_test

  ! Program to test fifo_c.c and fifo_f.f90
  !
  ! Usage:
  !  icc -c fifo_c.c
  !  ifort -c fifo_f.f90 
  !  ifort fifo_test.F90 fifo_f.o fifo_c.o -lpng
  !
  ! -DTEST_GRAPHTERM for escaped terminal output
  ! -DTEST_STDOUT for piping output to stdout
  ! -DDEBUG_FIFO for debugging

  use fifo_f
  implicit none
  
  integer,parameter :: min_bytes=1500, width=400, height=250, ncolors=256, line_max=80
  integer :: img_colors(3,ncolors)
  character :: img_pixels(width, height), read_buf(line_max+1)
  character,allocatable :: outbuf(:)

  real, parameter :: PI=3.1415927
  real :: data_values(width, height), dx, dy

  character(len=*), parameter :: png_file = "testpng.png"
  character(len=*), parameter :: read_file = "testin.fifo"
#ifdef TEST_STDOUT
  character(len=*), parameter :: pipe_file = "-"
#else
  character(len=*), parameter :: pipe_file = "testout.fifo"
#endif

  character(len=*), parameter :: new_channel = "channel:channel2"
  integer i, j, k, kstep, p, pipe_num, read_fd

  character(len=*), parameter :: data_url_prefix = "data:image/png;base64,"
  integer, parameter :: hello_bytes=88
  integer(kind=1) :: hello_data(hello_bytes)
  character(len=hello_bytes) :: hello_str
  character(len=2*hello_bytes) :: hello_png_hex = &
                  '89504E470D0A1A0A0000000D4948445200000026000000040100000000CA22703E0000001F49444154789C63888&
                  &FFFFFEF054364E05DA10E06E1D0AB616B80EC93621D0083AA0A15985D4B3A0000000049454E44AE426082'

  character(len=81) :: labelstr="", linestr=""
  integer :: ngrid, max_bytes, status
  integer :: reverse=1
  integer :: count=0

  ! Initialize simple image
  do j=1,height
     img_pixels(:,j) = char(j-1)
  end do

  ! Generate simple color map
  do p=1,ncolors
     img_colors(1,p) = p-1
     img_colors(2,p) = 100
     img_colors(3,p) = ncolors-p
  end do

  ngrid = width * height
  max_bytes = ngrid + min_bytes

  allocate(outbuf(max_bytes))   ! Image output buffer

#ifdef DEBUG_FIFO
  write(*,*) "fifo_test: Fortran values for width, height, palette_size, out_bytes_max, DATA_URL_ENC, VIRIDIS_CMAP(1,1)", &
       width, height, ncolors, max_bytes, DATA_URL_ENC, VIRIDIS_CMAP(1,1)
  write(*,*) "fifo_test: Fortran pointers for img, colors, outbuf", loc(img_pixels), loc(img_colors), loc(outbuf)
#endif

  ! Render simple image to buffer as raw PNG data
  count = render_image(img_pixels, outbuf, NO_ENC, reverse, img_colors)

  if (count .le. 0) then
     call stderr( "fifo_test: Error in rendering PNG")
  else
     ! Write test PNG file
     open(unit=11, file=png_file, status="replace", access="stream")
     write(11) outbuf(1:count)
     close(11)
     call stderr( "fifo_test: Created test PNG file "//png_file )
  endif
  if ( allocated(outbuf) ) deallocate(outbuf)

  ! Simple test PNG data
  read(hello_png_hex, '(88Z2)') hello_data  ! Convert hexadecimal data containing PNG binary to integer array
  do i=1,hello_bytes
     hello_str(i:i) = char(hello_data(i))   ! Convert integer array to string containing binary data as characters
  end do

  ! Open input pipe
  call stderr( "fifo_test: Reading from named pipe "//read_file )
  read_fd = open_read_fd(read_file)

  call stderr( "fifo_test: Writing to named pipe "//pipe_file )

#ifdef TEST_GRAPHTERM
  ! Allocate output pipe
  pipe_num = allocate_file_pipe(pipe_file, GRAPHTERM_ENC)
#else
  ! Allocate output pipe
  pipe_num = allocate_file_pipe(pipe_file)

  ! Write simple PNG file to illustrate how image output from other graphics packages can be transmitted via fifofum
  status = write_str_to_pipe(pipe_num, data_url_prefix)
  status = write_str_to_pipe(pipe_num, hello_str, encoded=1, end_line=1)
  status = write_str_to_pipe(pipe_num, "Starting...", end_line=1)
  status = c_sleep(5)   ! Sleep for a while
#endif


  dx = 1.0 / width
  dy = 1.0 / height

  kstep = max(1,width/25)

  do k=1,1000000*kstep, kstep
     status = c_sleep(1)   ! Sleep for a while
     do
        ! try to read text from input pipe
        count = read_from_fd(read_fd, read_buf, line_max+1)
        if (count <= 0) exit
        write(linestr,*) read_buf(1:count)
        call stderr("fifo_test: READ PIPE:"//linestr(1:min(count,81)))
     end do

     ! Traveling sine-wave animation
     do j=1,height
        do i=1,width
           data_values(i,j) = sin((i+k)*dx*2*PI) * sin(j*dy*PI)
        end do
     end do

     ! Mask small values
     where(abs(data_values) < 0.5) data_values = 0.0

#ifdef TEST_GRAPHTERM
     ! Write image to output pipe
     count = fifo_plot2d(pipe_num, data_values, colormap_code=1, opacity=0.9, &
                         undef_value=0.0, undef_color=15, transp_color=15)
#else
     if (i > 26) then
         if (mod(i,2) == 1) then 
             count = write_str_to_pipe(pipe_num, "channel:channel1", end_line=1)
         else
             count = write_str_to_pipe(pipe_num, "channel:channel2", end_line=1)
         end if
     end if
     write(labelstr, *) "k=", k
     ! Write image to output pipe (with label)
     count = fifo_plot2d(pipe_num, data_values, label=trim(labelstr), colormap_code=1, opacity=0.9, &
                         undef_value=0.0, undef_color=15, transp_color=15)
#endif

  end do

  status = c_close(read_fd)   ! Close input pipe
  call free_pipe(pipe_num)    ! Close output pipe
  
end program fifo_test
      
