module fifo_f

  ! Fortran wrapper for fifo_c.c
  !
  ! Usage:
  !   icc fifo_c.c
  !   ifort -c fifo_f.F90
  !   ifort testfifo.F90 fifo_f.o fifo_c.o -lpng
  
  use, intrinsic :: iso_c_binding
  implicit none

  integer(c_int), bind(c,name="VIRIDIS_CMAP")  :: VIRIDIS_CMAP(3,256)            ! Viridis full 256 color map
  integer(c_int), bind(c,name="VIRIDIS_PLUS_CMAP")  :: VIRIDIS_PLUS_CMAP(3,256)  ! Viridis 240+plus other colors map

  ! Encoding values
  integer, parameter :: NO_ENC        =  0 ! none (raw bytes)
  integer, parameter :: B64_ENC       =  1 ! Base64
  integer, parameter :: DATA_URL_ENC  =  2 ! Base64 with data URL prefix+new line suffix (for fifofum.py)
  integer, parameter :: B64_LINE_ENC  = -1 ! Base64, broken into 80 character lines
  integer, parameter :: GRAPHTERM_ENC = -2 ! Base64 with GraphTerm prefix and suffix
  ! (Note: Using C binding to access these from fifo_c generates byte alignment warning messages; hence defined here again)

  interface

      ! Wrappers for most, but not all, exposed fifo_c.c functions (see also auxiliary functions below for the rest)
     
      ! Function that initializes writing of colormapped image data to open file descriptor.
      ! Returns pipe number (>= 0) on success or negative value on error
      ! (See allocate_file_pipe for meaning of encoding parameter)
      ! C prototype:
      !   allocate_pipe(int write_fd, int encoding, int keep_open)

      function allocate_pipe(fd, encoding, keep_open) bind(c)
          use iso_c_binding
          implicit none
          integer(c_int) :: allocate_pipe
          integer(c_int), value, intent(in) :: fd, encoding, keep_open
      end function allocate_pipe

      ! Flush, returning 0 on success, or -1 on error
      ! C prototype:
      !   void flush_pipe(int pipe_num);

      subroutine flush_pipe(pipe_num) bind(c)
          use iso_c_binding
          implicit none
          integer(c_int), value, intent(in) :: pipe_num
      end subroutine flush_pipe

      ! Write to pipe, returning number of bytes written, or -1 on error
      ! C prototype:
      !   int write_to_pipe(int pipe_num, const void *buf, int nbyte);

      function write_to_pipe(pipe_num, buf, nbyte) bind(c)
          use iso_c_binding
          implicit none
          integer(c_int) write_to_pipe
          character(kind=c_char), intent(in) :: buf(*)
          integer(c_int), value, intent(in) :: pipe_num, nbyte
      end function write_to_pipe

      ! C prototype:
      !   void free_pipe(int pipe_num);

      ! Write encoded data to pipe
      ! C prototype:
      !   void write_encoded(int pipe_num, const void *buf, int nbyte);

      subroutine write_encoded(pipe_num, buf, nbyte) bind(c)
          use iso_c_binding
          implicit none
          character(kind=c_char), intent(in) :: buf(*)
          integer(c_int), value, intent(in) :: pipe_num, nbyte
      end subroutine write_encoded

      ! C prototype:
      !   void free_pipe(int pipe_num);

      subroutine free_pipe(pipe_num) bind(c)
          use iso_c_binding
          implicit none
          integer(c_int), value, intent(in) :: pipe_num
      end subroutine free_pipe

      ! Read upto count bytes from fd, returning number of bytes read, or -1
      ! C prototype:
      !    int read_from_fd(int fd, char *buf, int count);
       
      function read_from_fd(fd, buf, count) bind(c)
          use iso_c_binding
          implicit none
          integer(c_int) :: read_from_fd
          character(kind=c_char), intent(out) :: buf(*)
          integer(c_int), value, intent(in) :: fd, count
      end function read_from_fd

   end interface

   interface

      ! Wrappers for useful C functions

      ! Close file descriptor
      ! C prototype:
      !   int close(int fd);

      function c_close(fd) bind(c, name="close")
          use iso_c_binding
          implicit none
          integer(c_int) :: c_close
          integer(c_int), value, intent(in) :: fd
      end function c_close

      ! Sleep for seconds
      ! C prototype:
      !   unsigned int sleep(unsigned int seconds);

      function c_sleep (seconds)  bind(c, name="sleep")
          use iso_c_binding
          implicit none
          integer(c_int) :: c_sleep
          integer(c_int), intent(in), value :: seconds
      end function c_sleep

   end interface

   interface

      ! FOR INTERNAL USE ONLY (by auxiliary functions)

      ! Write colormapped image data to supplied character buffer,
      ! returning number of bytes written, or negative value in case of error.
      ! img is a char(height, width) array with 0-255 colormap index values.
      ! colors is a int(palette_size,3) array containing 0-255 RGB colormap triplets.
      ! (See allocate_file_pipe for meaning of encoding parameter)
      ! If generated image data is more than out_bytes_max bytes, the negative of the required buffer size is returned as the error code.
      ! A safe value for out_bytes_max would be 1500 + width*height. (Multiply by 1.33, if Base64 encoded)
      ! C prototype:
      !   int render_image(char *img, int width, int height, char *outbuf, int out_bytes_max, int encoding, int reverse, int *colors, int palette_size);

      function tem_render_image(img, width, height, outbuf, out_bytes_max, encoding, &
                                reverse, colors, palette_size, alphas, n_alphas) bind(c, name="render_image")
          use iso_c_binding
          implicit none
          integer(c_int) tem_render_image
          character(kind=c_char), intent(in) :: img(*)
          character(kind=c_char), intent(out) :: outbuf(*)
          integer(c_int), value, intent(in) :: width, height, out_bytes_max, encoding
          integer(c_int), value, intent(in) :: reverse, palette_size, n_alphas
          integer(c_int), intent(in) :: colors(*), alphas(*)
      end function tem_render_image


      function tem_encode_image(pipe_num, img, width, height, &
                                reverse, colors, palette_size, alphas, n_alphas) bind(c, name="encode_image")
          use iso_c_binding
          implicit none
          integer(c_int) tem_encode_image
          character(kind=c_char), intent(in) :: img(*)
          integer(c_int), value, intent(in) :: pipe_num, width, height, reverse, palette_size, n_alphas
          integer(c_int), intent(in) :: colors(*), alphas(*)
      end function tem_encode_image

      
      function tem_allocate_file_pipe(path, encoding, named_pipe) bind(c, name="allocate_file_pipe")
          use iso_c_binding
          implicit none
          integer(c_int) :: tem_allocate_file_pipe
          character(kind=c_char), intent(in) :: path(*)
          integer(c_int), value, intent(in) :: encoding, named_pipe
      end function tem_allocate_file_pipe

      function tem_open_read_fd(path) bind(c, name="open_read_fd")
          use iso_c_binding
          implicit none
          integer(c_int) :: tem_open_read_fd
          character(kind=c_char), intent(in) :: path(*)
      end function tem_open_read_fd

   end interface

contains

  ! AUXILIARY FUNCTIONS (to handle null-terminated string arguments, optional arguments etc

  ! Write colormapped image data to supplied character buffer,
  ! returning number of bytes written, or negative value in case of error.
  ! img is a char(height, width) array with 0-255 colormap index values.
  ! (See allocate_file_pipe for meaning of encoding parameter, which defaults to NO_ENC)
  ! colors is a int(palette_size,3) array containing 0-255 RGB colormap triplets.
  ! If colors is omitted, a Viridis color map is used by default.
  ! If generated image data is more than out_bytes_max bytes, the negative of the required buffer size is returned as the error code.
  ! A safe value for out_bytes_max would be 1500 + width*height. (Multiply by 1.33, if Base64 encoded)
  ! C prototype:
  !   int render_image(char *img, int width, int height, char *outbuf, int out_bytes_max, int encoding, int reverse, int *colors, int palette_size);

  function render_image(img, outbuf, encoding, reverse, colors, alphas)
      use iso_c_binding
      implicit none
      integer(c_int) render_image
      character(kind=c_char), intent(in) :: img(1:,1:)
      character(kind=c_char), intent(out) :: outbuf(1:)
      integer(c_int), OPTIONAL, intent(in) :: colors(1:,1:), alphas(1:)
      integer(c_int), OPTIONAL, intent(in) :: encoding, reverse
  
      integer(c_int) ::  tem_encoding=NO_ENC, tem_reverse=0, dummy(0:0)

      if (present(encoding)) tem_encoding = encoding
      if (present(reverse)) tem_reverse = reverse

      if (present(colors)) then
         if (size(colors,1) /= 3) call stderr("render_image: ERROR colors must be a 3xn array", exit=1)

         render_image = tem_render_image(img, size(img,1), size(img,2), outbuf, size(outbuf), tem_encoding, &
                                         tem_reverse, colors, size(colors,2), dummy, 0)
      else
         render_image = tem_render_image(img, size(img,1), size(img,2), outbuf, size(outbuf), tem_encoding, &
                                         tem_reverse, VIRIDIS_CMAP, size(VIRIDIS_CMAP,2), dummy, 0)
      end if
  end function render_image


  ! Writes colormapped image data to initialized file/pipe/character buffer.
  ! img is a char(width, height) array with 0-255 colormap index values.
  ! colors is a integer(3,palette_size) array containing 0-255 RGB colormap triplets.
  ! If colors is omitted, a Viridis color map is used by default.
  ! reverse=1 reverses the color map.
  ! Return number of characters converted on success, or negative value on error.
  ! C prototype:
  !   int encode_image(int pipe_num, char *img, int width, int height,
  !                  int reverse, int *colors, int palette_size, int *alphas, int n_alphas);

  function encode_image(pipe_num, img, reverse, colors, alphas)
      use iso_c_binding
      implicit none
      integer(c_int) encode_image
      integer(c_int), intent(in) :: pipe_num
      character(kind=c_char), intent(in) :: img(1:,1:)
      integer(c_int), OPTIONAL, intent(in) :: reverse
      integer(c_int), OPTIONAL, intent(in) :: colors(1:,1:), alphas(1:)

      integer(c_int) ::  tem_reverse=0, dummy(0:0)

      if (present(reverse)) tem_reverse = reverse

      if (present(colors)) then
          if (size(colors,1) /= 3) call stderr("encode_image: ERROR colors must be a 3xn array", exit=1)

          if (present(alphas)) then
              encode_image = tem_encode_image(pipe_num, img, size(img,1), size(img,2), &
                                              tem_reverse, colors, size(colors,2), alphas, size(alphas))
          else
              encode_image = tem_encode_image(pipe_num, img, size(img,1), size(img,2), &
                                              tem_reverse, colors, size(colors,2), dummy, 0)
          endif
      else
          encode_image = tem_encode_image(pipe_num, img, size(img,1), size(img,2), &
                                          tem_reverse, VIRIDIS_CMAP, size(VIRIDIS_CMAP,2), dummy, 0)
      endif
  end function encode_image

  
  ! Open a file/named-pipe(FIFO),
  ! returning file descriptor number of file/named pipe or negative value in case of error.
  ! A path value of "-" uses standard output. (DEFAULT)
  ! encoding may be: NO_ENC        (0)  for none (raw bytes)
  !                  B64_ENC       (1)  for Base64
  !                  DATA_URL_ENC  (2)  for Base64 with data URL prefix+new line suffix DEFAULT (for fifofum.py)
  !                  B64_LINE_ENC  (-1) for Base64, broken into 80 character lines
  !                  GRAPHTERM_ENC (-2) for Base64 with GraphTerm prefix and suffix
  ! If named_pipe, a FIFO file is opened (if needed) and kept open even after data is output. (=1 by DEFAULT)
  ! C prototype:
  ! int allocate_file_pipe(const char *path, int encoding, int named_pipe);

  function allocate_file_pipe(path, encoding, named_pipe)
      implicit none
      integer :: allocate_file_pipe
      character(len=*), OPTIONAL, intent(in) :: path
      integer, OPTIONAL, intent(in) :: encoding, named_pipe

      integer, parameter :: MAXPATH = 255
      character(len=MAXPATH+1,kind=c_char) :: c_path

      integer :: tem_encoding=DATA_URL_ENC, tem_named_pipe=1

      if (len(path) > MAXPATH) call stderr("allocate_file_pipe: ERROR Path too long - "//path, exit=1)

      if (present(encoding)) tem_encoding = encoding
      if (present(named_pipe)) tem_named_pipe = named_pipe

      if (present(path)) then
          c_path = trim(path)//c_null_char
      else
          c_path = "-"//c_null_char
      endif
      allocate_file_pipe = tem_allocate_file_pipe(c_path, tem_encoding, tem_named_pipe)
    end function allocate_file_pipe

  ! Create and open named pipe for reading, returning file descriptor (>= 0)
  ! C prototype:
  !   int open_read_fd(const char *path);

  function open_read_fd(path)
      implicit none
      integer :: open_read_fd
      character(len=*), intent(in) :: path
      character(len=len_trim(path)+1,kind=c_char) :: c_path

      c_path = trim(path)//c_null_char
      open_read_fd = tem_open_read_fd(c_path)
  end function open_read_fd

  ! Write string to pipe, returning number of bytes written, or -1 on error,
  ! optionally ending the line by appending a new_line character (end_line=1).
  ! If encoded=1, write encoded data.
  ! (Invokes write_to_pipe)

  function write_str_to_pipe(pipe_num, str, end_line, encoded)
      implicit none
      integer :: write_str_to_pipe
      integer, intent(in) :: pipe_num
      character(len=*), intent(in) :: str
      integer, intent(in), OPTIONAL :: end_line, encoded

      if (present(encoded)) then
         call write_encoded(pipe_num, str, len(str))
         call write_encoded(pipe_num, "", 0)   ! Flush encoding buffer
      else
          write_str_to_pipe = write_to_pipe(pipe_num, str, len(str))
      end if

      if (present(end_line)) then
          write_str_to_pipe = write_to_pipe(pipe_num, new_line("a"), len(new_line("a")) )
          call flush_pipe(pipe_num)
      end if
  end function write_str_to_pipe

  ! Scale and plot a 2-dimensional real data field as an image (using 240 colors, plus 16 basic colors)
  ! colormap_code = 0 => default (Viridis)
  !                 1 => Viridis (yellow->green)
  !                 2 => grayscale (black->white)
  !                 3 => grayalpha (transparent black->opaque white)
  ! (Negative colormap codes reverse the corresponding colormap)
  ! opacity ranges from 0.0 (transparent) to 1.0 (opaque)
  ! min_value:max_value spans the full color table. If omitted, they are determined from the data.
  ! undef_value and undef_color can be used to shade undefined values.
  ! If undef_value is specified without undef_color, a default undef_color of 0 is used.
  ! If transp_color >= 0, that particular color index is made transparent (ignored for grayalpha colormap).
  ! undef_color/transp_color can be a basic color (0-15), or a color in the colormap (16-255).
  ! If transp_color or undef_color is specified, it will also be used for out-of-range plot values.
  ! colors is an optional colormap array (as in encode_image)
  !
  ! Basic colors 0-7:   Black,  White,     Red,  Lime Green,  Blue,  Cyan,  Magenta,  Yellow
  ! basic colors 8-15: Silver,   Gray,  Maroon,  Dark Green,  Navy,  Teal,   Purple,   Olive
  function fifo_plot2d(pipe_num, field, label, colormap_code, opacity, min_value, max_value, &
                       undef_value, undef_color, transp_color, colors)
      use iso_c_binding
      implicit none
      integer fifo_plot2d
      integer, intent(in) :: pipe_num
      real, intent(in) :: field(1:,1:)
      character(len=*), OPTIONAL, intent(in) :: label
      integer(c_int), OPTIONAL, intent(in) :: colormap_code
      real, OPTIONAL, intent(in) :: opacity,  min_value, max_value, undef_value
      integer, OPTIONAL, intent(in) :: undef_color, transp_color
      integer(c_int), OPTIONAL, intent(in) :: colors(1:,1:)

      integer, parameter :: BASIC_COLORS=16, MAX_COLORS=256

      integer :: colormap(3,MAX_COLORS), reverse=0, n_colors=MAX_COLORS-BASIC_COLORS
      integer :: alphas(256), n_alphas=0
      character, dimension(size(field,1), size(field,2)) :: field_pixels
      character(len=81) :: line_buf, line_buf2
      real :: field_min, field_max, plot_min, plot_max, plot_scale
      integer :: status, field_sec, i, igray

      integer :: tem_colormap_code=0, tem_undef_color=0, tem_transp_color=-1, out_of_range_color=-1
      real :: tem_opacity = 1.0

      if (present(colormap_code)) tem_colormap_code = max(-3,min(3,colormap_code))
      if (present(opacity)) tem_opacity = max(0.0,min(1.0,opacity))
      if (present(undef_color)) tem_undef_color = max(0,min(255,undef_color))
      if (present(transp_color)) tem_transp_color = max(-1,min(255,transp_color))

      if (tem_transp_color >= 0) then
         out_of_range_color = tem_transp_color
      else if (present(undef_color) .or. present(undef_value)) then
         out_of_range_color = tem_undef_color
      end if

      if (tem_colormap_code == 0) tem_colormap_code = 1

      if (tem_colormap_code < 0) then
         tem_colormap_code = -tem_colormap_code
         reverse = 1
      end if

      if (tem_colormap_code >= 2) then
         ! Grayscale/transparent-grayscale colormap
         do i=1,BASIC_COLORS
            colormap(:,i) = VIRIDIS_PLUS_CMAP(:,i)
         end do
         do i=BASIC_COLORS+1,MAX_COLORS
            ! Grayscale
            igray = (255*(i-BASIC_COLORS-1))/(MAX_COLORS-BASIC_COLORS-1)
            if (reverse > 0) then
               colormap(:,i) = 255 - igray
            else
               colormap(:,i) = igray
            end if
         end do
      else
         ! Viridis plus colormap
         colormap(:,:) = VIRIDIS_PLUS_CMAP(:,:)
      end if

      if (tem_colormap_code == 3) then
         ! Transparent grayscale
         n_alphas = MAX_COLORS
         alphas(1:BASIC_COLORS) = 255
         alphas(BASIC_COLORS+1:MAX_COLORS) = colormap(1,BASIC_COLORS+1:MAX_COLORS)
      else if ( tem_transp_color >= 0 .or. tem_opacity < 1.0) then
         ! Transparent color/image
         n_alphas = MAX_COLORS
         alphas(1:BASIC_COLORS) = 255
         alphas(BASIC_COLORS+1:MAX_COLORS) = 255*tem_opacity
         if (tem_transp_color >= 0) alphas(tem_transp_color+1) = 0
      else
         n_alphas = 0
      end if

      ! find max/min of field and scale it
      if (present(undef_value)) then
          if (count(field /= undef_value) == 0) then
              field_min = undef_value
              field_max = undef_value
          else
              field_min = minval(field, mask=(field /= undef_value))
              field_max = maxval(field, mask=(field /= undef_value))
          endif
      else
          field_min = minval(field)
          field_max = maxval(field)
      endif

      if (present(min_value)) then
         plot_min = min_value
      else
         plot_min = field_min
      endif

      if (present(max_value)) then
         plot_max = max_value
      else
         plot_max = field_max
      endif

      if (plot_max > plot_min) then
         plot_scale = (n_colors - 1) / (plot_max - plot_min)
      else
         plot_scale = 1.0
      end if

      if (present(undef_value)) then
          where(field == undef_value)
             field_pixels = char(tem_undef_color)
          elsewhere(field < plot_min .or. field > plot_max)
             field_pixels = char(out_of_range_color)
          elsewhere
             field_pixels = char( BASIC_COLORS + max(0,min(255,nint( (field - plot_min) * plot_scale))) )
          endwhere
      else if (out_of_range_color >= 0) then
          where(field < plot_min .or. field > plot_max)
             field_pixels = char(out_of_range_color)
          elsewhere
             field_pixels = char( BASIC_COLORS + max(0,min(255,nint( (field - plot_min) * plot_scale))) )
          endwhere
      else
          field_pixels = char( BASIC_COLORS + max(0,min(255,nint( (field - plot_min) * plot_scale))) )
      end if

      if (present(label)) then
          write(line_buf, '(a,g12.5,a,g12.5)') " Max=", plot_max, ", Min=", plot_min
          if (present(min_value) .or. present(max_value)) then
             write(line_buf2, '(a,g12.5,a,g12.5)') ", DataMax=", field_max, ", DataMin=", field_min
          else
             line_buf2 = ""
          end if
          status = write_str_to_pipe(pipe_num, label//trim(line_buf)//trim(line_buf2), end_line=1)
      end if

      if (present(colors)) then
          ! User-defined colormap
          if (size(colors,1) /= 3) call stderr("fifo_plot2d: ERROR colors must be a 3x256 array", exit=1)
          if (size(colors,2) /= MAX_COLORS) call stderr("fifo_plot2d: ERROR colors must be a 3x256 array", exit=1)
          status = encode_image(pipe_num, field_pixels, reverse, colors, alphas(1:n_alphas) )
      else
          status = encode_image(pipe_num, field_pixels, reverse, colormap, alphas(1:n_alphas))
      end if

      fifo_plot2d = status
  end function fifo_plot2d
      
  ! From: fortranwiki.org
  subroutine stderr(message, exit)
      ! "@(#) stderr writes a message to standard error using a standard f2003 method"
      use iso_fortran_env, only : error_UNIT ! access computing environment
      character(len=*) :: message
      integer, OPTIONAL :: exit

      write(error_unit,'(a)') message ! write message to standard error

      if (present(exit)) then
         stop 1
      end if
  end subroutine stderr

  ! From: fortranwiki.org
  ! This is a simple function to search for an available unit.
  ! LUN_MIN and LUN_MAX define the range of possible LUNs to check.
  ! The UNIT value is returned by the function, and also by the optional
  ! argument. This allows the function to be used directly in an OPEN
  ! statement, and optionally save the result in a local variable.
  ! If no units are available, -1 is returned.
  integer function newunit(unit)
      implicit none
      integer, intent(out), optional :: unit
      ! local
      integer, parameter :: LUN_MIN=10, LUN_MAX=1000
      logical :: opened
      integer :: lun
      ! begin
      newunit=-1
      do lun=LUN_MIN,LUN_MAX
          inquire(unit=lun,opened=opened)
          if (.not. opened) then
              newunit=lun
              exit
          end if
      end do
      if (present(unit)) unit=newunit
  end function newunit

end module fifo_f
      
