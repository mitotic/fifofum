program test_graphterm

  ! Program to test simple animation of wave propagation using the fifofum library within GraphTerm
  !
  ! Usage:
  !  icc -c fifo_c.c
  !  ifort -c -r8 fifo_f.f90 
  !  ifort -o test_graphterm -r8 test_graphterm.F90 fifo_f.o fifo_c.o -lpng
  !  ./test_graphterm    # within GraphTerm
  !
  ! -DDEBUG_FIFO for debugging

  use fifo_f
  implicit none
  
  integer,parameter ::  width=400, height=250, ncolors=256, line_max=80
  character :: read_buf(line_max+1)
  character(len=81) :: labelstr="", linestr=""

  character(len=*), parameter :: read_file = "testin.fifo"
  character(len=*), parameter :: pipe_file = "-"

  integer :: i, j, k, kstep, pipe_num, status
  integer :: count=0

  real, parameter :: PI=3.1415927
  real :: data_values(width, height), dx, dy


  call stderr("test_graphterm: animation")

  ! Allocate output pipe
  pipe_num = allocate_file_pipe(pipe_file, GRAPHTERM_ENC)

  dx = 1.0 / width
  dy = 1.0 / height

  kstep = max(1,width/25)

  do k=1,1000000*kstep, kstep
     status = c_sleep(1)   ! Sleep for a while

     ! Traveling sine-wave animation
     do j=1,height
        do i=1,width
           data_values(i,j) = sin((i+k)*dx*2*PI) * sin(j*dy*PI)
        end do
     end do

     ! Mask small values
     where(abs(data_values) < 0.5) data_values = 0.0

     ! Write image to output pipe
     count = fifo_plot2d(pipe_num, data_values, colormap_code=1, opacity=0.9, &
                         undef_value=0.0, undef_color=15, transp_color=15)

  end do

  call free_pipe(pipe_num)    ! Close output pipe
  
end program test_graphterm
      
