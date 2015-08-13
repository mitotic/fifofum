program test_other

  ! Program to test streaming of image files created by another graphics package
  !
  ! Usage:
  !  icc -c -DFIFO_NO_PNG fifo_c.c
  !  ifort -c -r8 fifo_f.f90 
  !  ifort -o test_other -r8 test_other.F90 fifo_f.o fifo_c.o -lpng
  !  ./test_other
  !
  ! -DTEST_STDOUT for piping output to stdout
  ! -DDEBUG_FIFO for debugging

  use fifo_f
  implicit none
  
#ifdef TEST_STDOUT
  character(len=*), parameter :: pipe_file = "-"
#else
  character(len=*), parameter :: pipe_file = "testout.fifo"
#endif

  character(len=*), parameter :: data_url_prefix = "data:image/png;base64,"
  integer, parameter :: hello_bytes=88
  integer(kind=1) :: hello_data(hello_bytes)
  character(len=hello_bytes) :: hello_str
  character(len=2*hello_bytes) :: hello_png_hex = &
                  '89504E470D0A1A0A0000000D4948445200000026000000040100000000CA22703E0000001F49444154789C63888&
                  &FFFFFEF054364E05DA10E06E1D0AB616B80EC93621D0083AA0A15985D4B3A0000000049454E44AE426082'

  integer :: i, pipe_num, status

  ! Simple test PNG data
  read(hello_png_hex, '(88Z2)') hello_data  ! Convert hexadecimal data containing PNG binary to integer array
  do i=1,hello_bytes
     hello_str(i:i) = char(hello_data(i))   ! Convert integer array to string containing binary data as characters
  end do

  call stderr( "fifo_test: Writing to named pipe "//pipe_file )

  ! Allocate output pipe
  pipe_num = allocate_file_pipe(pipe_file)

  ! Write simple PNG file to illustrate how image output from other graphics packages can be transmitted via fifofum
  status = write_str_to_pipe(pipe_num, data_url_prefix)
  status = write_str_to_pipe(pipe_num, hello_str, encoded=1, end_line=1)
  status = write_str_to_pipe(pipe_num, "Sleeping...", end_line=1)

  call stderr("fifo_test: Sleeping ")
  status = c_sleep(30)   ! Sleep for a while

  call free_pipe(pipe_num)    ! Close output pipe
  
end program test_other
      
