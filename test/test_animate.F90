program test_animate

  ! Program to test simple animation of wave propagation using the fifonum library
  !
  ! Usage:
  !  icc -c fifo_c.c
  !  ifort -c -r8 fifo_f.f90 
  !  ifort -o test_animate -r8 test_animate.F90 fifo_f.o fifo_c.o -lpng
  !  ./test_animate &
  !  python fifofum.py --input=testin.fifo testout.fifo
  !
  ! -DTEST_STDOUT for piping output to stdout
  ! -DDEBUG_FIFO for debugging

  use fifo_f
  implicit none
  
  integer,parameter ::  width=400, height=250, ncolors=256, line_max=80
  character :: read_buf(line_max+1)
  character(len=81) :: labelstr="", linestr=""

  character(len=*), parameter :: new_channel = "channel:channel2"
  character(len=*), parameter :: read_file = "testin.fifo"
#ifdef TEST_STDOUT
  character(len=*), parameter :: pipe_file = "-"
#else
  character(len=*), parameter :: pipe_file = "testout.fifo"
#endif

  integer :: i, j, k, kstep, pipe_num, read_fd, status
  integer :: count=0

  real, parameter :: PI=3.1415927
  real :: data_values(width, height), dx, dy


  ! Open input pipe
  call stderr( "test_animate: Reading from named pipe "//read_file )
  read_fd = open_read_fd(read_file)

  call stderr( "test_animate: Writing to named pipe "//pipe_file )

  ! Allocate output pipe
  pipe_num = allocate_file_pipe(pipe_file)

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
        call stderr("test_animate: READ PIPE:"//linestr(1:min(count,81)))
     end do

     ! Traveling sine-wave animation
     do j=1,height
        do i=1,width
           data_values(i,j) = sin((i+k)*dx*2*PI) * sin(j*dy*PI)
        end do
     end do

     ! Mask small values
     where(abs(data_values) < 0.5) data_values = 0.0

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

  end do

  status = c_close(read_fd)   ! Close input pipe
  call free_pipe(pipe_num)    ! Close output pipe
  
end program test_animate
      
