program test_file

  ! Program to test simple image file creation using fifofum library
  !
  ! Usage:
  !  icc -c fifo_c.c
  !  ifort -c fifo_f.f90 
  !  ifort test_file.F90 fifo_f.o fifo_c.o -lpng
  !
  ! This should create the image file testpng.png
  !
  ! -DDEBUG_FIFO for debugging

  use fifo_f
  implicit none
  
  integer,parameter :: min_bytes=1500, width=400, height=250, ncolors=256
  integer :: img_colors(3,ncolors)
  character :: img_pixels(width, height)
  character,allocatable :: outbuf(:)

  character(len=*), parameter :: png_file = "testpng.png"
  integer i, j, p

  integer :: ngrid, max_bytes
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
  write(*,*) "test_file: Fortran values for width, height, palette_size, out_bytes_max, DATA_URL_ENC, VIRIDIS_CMAP(1,1)", &
       width, height, ncolors, max_bytes, DATA_URL_ENC, VIRIDIS_CMAP(1,1)
  write(*,*) "test_file: Fortran pointers for img, colors, outbuf", loc(img_pixels), loc(img_colors), loc(outbuf)
#endif

  ! Render simple image to buffer as raw PNG data
  count = render_image(img_pixels, outbuf, NO_ENC, reverse, img_colors)

  if (count .le. 0) then
     call stderr( "test_file: Error in rendering PNG")
  else
     ! Write test PNG file
     open(unit=11, file=png_file, status="replace", access="stream")
     write(11) outbuf(1:count)
     close(11)
     call stderr( "test_file: Created test PNG file "//png_file )
  endif
  if ( allocated(outbuf) ) deallocate(outbuf)

end program test_file
      
