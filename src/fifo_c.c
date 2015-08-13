/* fifo_c: FIFO amed pipe functions for streaming text and graphics

 -DTEST_MAIN to run test main program
 -DTEST_GRAPHTERM for escaped terminal output
 -DTEST_STDOUT for piping output to stdout
 -DDEBUG_FIFO for debug trace output
 -DFIFO_BLOCKING for blocking writes to named pipe
 -DFIFO_NO_PNG for compiling without the PNG library (display raw uncompressed images)

  To test:
      cc -DTEST_MAIN  fifo_c.c -lpng
      (On OS X, add options -I/opt/X11/include/libpng15 -L/opt/X11/lib)

      echo HELLO > testin.fifo  # in a different terminal
      cat < testout.fifo        # in a different terminal

      # To validate Base64 output
      base64 --decode -o tem.png -i testpng.b64
      cmp tem.png testpng.png

      # For web display

      cc -DTEST_MAIN -DTEST_STDOUT fifo_c.c -lpng
      ./a.out|python fifofum.py --input=_ _   # Load http://localhost:8008

      python fifofum.py --input=testin.fifo testout.fifo  # Load http://localhost:8008

      python fifofum.py --multiplex=1 --input=testin.fifo testout.fifo  # Load http://localhost:8008 for multi-channel output
 */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

/* Fortran-accessible GLOBAL variables (not static) */
/* Encoding values GLOBAL */
int NO_ENC        =  0; /* none (raw bytes) */
int B64_ENC       =  1; /* Base64 */
int DATA_URL_ENC  =  2; /* Base64 with image data URL prefix+new line suffix (for fifofum.py) */
int B64_LINE_ENC  = -1; /* Base64, broken into 80 character lines */
int GRAPHTERM_ENC = -2; /* Base64 with GraphTerm prefix and suffix */

/* Viridis color map (256 RGB triplets) from matplotlib (https://github.com/BIDS/colormap/blob/master/option_d.py) GLOBAL */
int VIRIDIS_CMAP[3*256] = {
 68,  1, 84,   68,  2, 86,   69,  4, 87,   69,  5, 89,   70,  7, 90,   70,  8, 92,   70, 10, 93,   70, 11, 94,  
 71, 13, 96,   71, 14, 97,   71, 16, 99,   71, 17,100,   71, 19,101,   72, 20,103,   72, 22,104,   72, 23,105,  
 72, 24,106,   72, 26,108,   72, 27,109,   72, 28,110,   72, 29,111,   72, 31,112,   72, 32,113,   72, 33,115,  
 72, 35,116,   72, 36,117,   72, 37,118,   72, 38,119,   72, 40,120,   72, 41,121,   71, 42,122,   71, 44,122,  
 71, 45,123,   71, 46,124,   71, 47,125,   70, 48,126,   70, 50,126,   70, 51,127,   70, 52,128,   69, 53,129,  
 69, 55,129,   69, 56,130,   68, 57,131,   68, 58,131,   68, 59,132,   67, 61,132,   67, 62,133,   66, 63,133,  
 66, 64,134,   66, 65,134,   65, 66,135,   65, 68,135,   64, 69,136,   64, 70,136,   63, 71,136,   63, 72,137,  
 62, 73,137,   62, 74,137,   62, 76,138,   61, 77,138,   61, 78,138,   60, 79,138,   60, 80,139,   59, 81,139,  
 59, 82,139,   58, 83,139,   58, 84,140,   57, 85,140,   57, 86,140,   56, 88,140,   56, 89,140,   55, 90,140,  
 55, 91,141,   54, 92,141,   54, 93,141,   53, 94,141,   53, 95,141,   52, 96,141,   52, 97,141,   51, 98,141,  
 51, 99,141,   50,100,142,   50,101,142,   49,102,142,   49,103,142,   49,104,142,   48,105,142,   48,106,142,  
 47,107,142,   47,108,142,   46,109,142,   46,110,142,   46,111,142,   45,112,142,   45,113,142,   44,113,142,  
 44,114,142,   44,115,142,   43,116,142,   43,117,142,   42,118,142,   42,119,142,   42,120,142,   41,121,142,  
 41,122,142,   41,123,142,   40,124,142,   40,125,142,   39,126,142,   39,127,142,   39,128,142,   38,129,142,  
 38,130,142,   38,130,142,   37,131,142,   37,132,142,   37,133,142,   36,134,142,   36,135,142,   35,136,142,  
 35,137,142,   35,138,141,   34,139,141,   34,140,141,   34,141,141,   33,142,141,   33,143,141,   33,144,141,  
 33,145,140,   32,146,140,   32,146,140,   32,147,140,   31,148,140,   31,149,139,   31,150,139,   31,151,139,  
 31,152,139,   31,153,138,   31,154,138,   30,155,138,   30,156,137,   30,157,137,   31,158,137,   31,159,136,  
 31,160,136,   31,161,136,   31,161,135,   31,162,135,   32,163,134,   32,164,134,   33,165,133,   33,166,133,  
 34,167,133,   34,168,132,   35,169,131,   36,170,131,   37,171,130,   37,172,130,   38,173,129,   39,173,129,  
 40,174,128,   41,175,127,   42,176,127,   44,177,126,   45,178,125,   46,179,124,   47,180,124,   49,181,123,  
 50,182,122,   52,182,121,   53,183,121,   55,184,120,   56,185,119,   58,186,118,   59,187,117,   61,188,116,  
 63,188,115,   64,189,114,   66,190,113,   68,191,112,   70,192,111,   72,193,110,   74,193,109,   76,194,108,  
 78,195,107,   80,196,106,   82,197,105,   84,197,104,   86,198,103,   88,199,101,   90,200,100,   92,200, 99,  
 94,201, 98,   96,202, 96,   99,203, 95,  101,203, 94,  103,204, 92,  105,205, 91,  108,205, 90,  110,206, 88,  
112,207, 87,  115,208, 86,  117,208, 84,  119,209, 83,  122,209, 81,  124,210, 80,  127,211, 78,  129,211, 77,  
132,212, 75,  134,213, 73,  137,213, 72,  139,214, 70,  142,214, 69,  144,215, 67,  147,215, 65,  149,216, 64,  
152,216, 62,  155,217, 60,  157,217, 59,  160,218, 57,  162,218, 55,  165,219, 54,  168,219, 52,  170,220, 50,  
173,220, 48,  176,221, 47,  178,221, 45,  181,222, 43,  184,222, 41,  186,222, 40,  189,223, 38,  192,223, 37,  
194,223, 35,  197,224, 33,  200,224, 32,  202,225, 31,  205,225, 29,  208,225, 28,  210,226, 27,  213,226, 26,  
216,226, 25,  218,227, 25,  221,227, 24,  223,227, 24,  226,228, 24,  229,228, 25,  231,228, 25,  234,229, 26,  
236,229, 27,  239,229, 28,  241,229, 29,  244,230, 30,  246,230, 32,  248,230, 33,  251,231, 35,  253,231, 37
};


/* Viridis plus color map (16 basic colors + 240 RGB triplets) */
int VIRIDIS_PLUS_CMAP[3*256] = {
/*    Black,        White,          Red,   Lime Green,         Blue,         Cyan,      Magenta,       Yellow */
  0,  0,  0,  255,255,255,  255,  0,  0,    0,255,  0,    0,  0,255,    0,255,255,  255,  0,255,  255,255,  0,  
/*   Silver,         Gray,       Maroon,   Dark Green,         Navy,        Teal,        Purple,        Olive,*/
192,192,192,  128,128,128,  128,  0,  0,    0,128,  0,    0,  0,128,    0,128,128,  128,  0,128,   128,128, 0,
 /* VIRIDIS 240 */
 68,  1, 84,   68,  3, 86,   69,  4, 87,   69,  5, 89,   70,  7, 90,   70,  9, 92,   70, 10, 94,   71, 12, 95,  
 71, 14, 97,   71, 15, 98,   71, 17, 99,   71, 18,101,   72, 20,102,   72, 21,104,   72, 23,105,   72, 24,106,  
 72, 26,108,   72, 27,109,   72, 28,110,   72, 30,112,   72, 31,113,   72, 33,114,   72, 34,115,   72, 35,116,  
 72, 37,117,   72, 38,118,   72, 39,119,   72, 41,120,   71, 42,121,   71, 43,122,   71, 45,123,   71, 46,124,  
 71, 47,125,   70, 49,126,   70, 50,127,   70, 51,127,   69, 53,128,   69, 54,129,   69, 55,130,   68, 57,130,  
 68, 58,131,   68, 59,132,   67, 60,132,   67, 62,133,   66, 63,133,   66, 64,134,   66, 65,134,   65, 67,135,  
 65, 68,135,   64, 69,136,   64, 70,136,   63, 72,136,   63, 73,137,   62, 74,137,   62, 75,138,   61, 76,138,  
 61, 78,138,   60, 79,138,   60, 80,139,   59, 81,139,   59, 82,139,   58, 83,139,   58, 85,140,   57, 86,140,  
 56, 87,140,   56, 88,140,   55, 89,140,   55, 90,140,   54, 91,141,   54, 92,141,   53, 93,141,   53, 95,141,  
 52, 96,141,   52, 97,141,   51, 98,141,   51, 99,141,   50,100,142,   50,101,142,   49,102,142,   49,103,142,  
 48,104,142,   48,105,142,   48,106,142,   47,107,142,   47,108,142,   46,109,142,   46,110,142,   45,111,142,  
 45,112,142,   44,113,142,   44,114,142,   44,115,142,   43,116,142,   43,118,142,   42,119,142,   42,120,142,  
 42,121,142,   41,122,142,   41,123,142,   40,124,142,   40,125,142,   40,126,142,   39,127,142,   39,128,142,  
 38,129,142,   38,130,142,   38,131,142,   37,132,142,   37,133,142,   36,134,142,   36,135,142,   36,136,142,  
 35,137,142,   35,138,141,   35,139,141,   34,140,141,   34,141,141,   34,142,141,   33,143,141,   33,144,141,  
 33,145,140,   32,146,140,   32,147,140,   32,148,140,   31,149,140,   31,150,139,   31,151,139,   31,152,139,  
 31,153,138,   31,154,138,   30,155,138,   30,156,138,   30,157,137,   31,158,137,   31,159,136,   31,160,136,  
 31,161,136,   31,162,135,   32,163,135,   32,164,134,   32,165,134,   33,166,133,   33,167,133,   34,168,132,  
 35,169,132,   36,170,131,   36,171,130,   37,171,130,   38,172,129,   39,173,129,   40,174,128,   41,175,127,  
 43,176,126,   44,177,126,   45,178,125,   47,179,124,   48,180,123,   49,181,123,   51,182,122,   53,183,121,  
 54,184,120,   56,185,119,   57,186,118,   59,187,117,   61,188,116,   63,188,115,   65,189,114,   67,190,113,  
 69,191,112,   70,192,111,   72,193,110,   75,194,109,   77,195,108,   79,195,106,   81,196,105,   83,197,104,  
 85,198,103,   87,199,102,   90,200,100,   92,200, 99,   94,201, 98,   97,202, 96,   99,203, 95,  101,204, 93,  
104,204, 92,  106,205, 91,  109,206, 89,  111,207, 88,  114,207, 86,  116,208, 85,  119,209, 83,  121,209, 81,  
124,210, 80,  126,211, 78,  129,211, 77,  132,212, 75,  134,213, 73,  137,213, 72,  140,214, 70,  142,214, 68,  
145,215, 66,  148,216, 65,  151,216, 63,  153,217, 61,  156,217, 59,  159,218, 57,  162,218, 56,  165,219, 54,  
167,219, 52,  170,220, 50,  173,220, 48,  176,221, 46,  179,221, 45,  182,222, 43,  185,222, 41,  187,222, 39,  
190,223, 37,  193,223, 36,  196,224, 34,  199,224, 32,  202,224, 31,  205,225, 30,  207,225, 28,  210,226, 27,  
213,226, 26,  216,226, 25,  219,227, 25,  221,227, 24,  224,227, 24,  227,228, 24,  230,228, 25,  232,228, 25,  
235,229, 26,  238,229, 27,  240,229, 28,  243,230, 30,  246,230, 31,  248,230, 33,  251,231, 35,  253,231, 37
};

#ifdef FIFO_NO_PNG
#define IMAGE_TYPE "x-raw"
#else
#define IMAGE_TYPE "png"
#endif

#define DATA_URL_PREFIX_FMT "data:image/%s;base64,"
#define DATA_URL_SUFFIX "\n"

#define GRAPHTERM_PREFIX_FMT "\x1b[?1155;0h<!--gterm data display=block overwrite=yes-->image/%s;base64,"
#define GRAPHTERM_SUFFIX "\x1b[?1155l"

#define FIFO_LINEMAX 80

struct pipe_buffer {
    int pipe_num;
    int write_fd;
    int keep_open;
    int encoding;

    unsigned char *stream_ptr;       /*  location to write image stream  */
    int stream_len;                  /*  number of bytes written       */
    int stream_maxlen;               /*  number of bytes written       */

    unsigned char raw_bytes[3];      /*  octets for Base64 encoding */
    int raw_len;
    char encoded_line[FIFO_LINEMAX];     /* Base64 encoded line */
    int line_len;                    /*  number of bytes written       */
};

typedef struct pipe_buffer pipe_buffer;

#define FIFO_MAX_PIPES 50
static pipe_buffer pipe_list[FIFO_MAX_PIPES];
static int initialized = 0;

void reset_pipe(int pipe_num)
{
    if (pipe_num < 0 || pipe_num >= FIFO_MAX_PIPES)
      return;

    pipe_list[pipe_num].pipe_num = pipe_num;
    pipe_list[pipe_num].write_fd = -1;
    pipe_list[pipe_num].keep_open = 0;
    pipe_list[pipe_num].encoding = 0;

    pipe_list[pipe_num].stream_ptr = NULL;
    pipe_list[pipe_num].stream_len = 0;
    pipe_list[pipe_num].stream_maxlen = 0;

    pipe_list[pipe_num].raw_len = 0;
    pipe_list[pipe_num].line_len = 0;
}


void init_pipes()
{
    int i;
    initialized = 1;
    for (i=0; i<FIFO_MAX_PIPES; i++)
      reset_pipe(i);
}


/* Return 1 for valid pipe number, 0 otherwise. Also initialize, if need be */

int check_pipe_num(int pipe_num)
{
    if (!initialized)
        init_pipes();

    if (pipe_num < 0 || pipe_num >= FIFO_MAX_PIPES)
      return 0;

    if (pipe_list[pipe_num].write_fd < 0 && pipe_list[pipe_num].stream_ptr == NULL)
      return 0; /* Pipe not active */

    return 1;
}


/* Return pipe number (>=0) of next available free pipe, or -1, if none available (does not "allocate" pipe) */
int get_available_pipe()
{
    int i;
    check_pipe_num(0);
  
    for (i=0; i<FIFO_MAX_PIPES; i++) {
        if (pipe_list[i].write_fd < 0 && pipe_list[i].stream_ptr == NULL) {
	    reset_pipe(i);
	    return i;
	}
    }
    return -1;
}


void free_pipe(int pipe_num)
{

#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:free_pipe: %d\n", pipe_num);
#endif

    if (check_pipe_num(pipe_num)) {
      if (pipe_list[pipe_num].write_fd >= 0)
        close(pipe_list[pipe_num].write_fd);
    }

    reset_pipe(pipe_num);
}


void free_all_pipes()
{
    int i;
    for (i=0; i<FIFO_MAX_PIPES; i++)
      free_pipe(i);
}


/* Flush pipe */
void flush_pipe(int pipe_num)
{
    if (!check_pipe_num(pipe_num))
        return;

    if (pipe_list[pipe_num].write_fd < 0)
      return;

  fsync(pipe_list[pipe_num].write_fd);
}


/* Write to pipe, returning number of bytes written, or -1 on error */
int write_to_pipe(int pipe_num, const void *buf, int nbyte)
{
    if (!check_pipe_num(pipe_num))
        return -1;

    if (pipe_list[pipe_num].write_fd < 0)
      return -1;

  return write(pipe_list[pipe_num].write_fd, buf, nbyte);
}


/* Write to pipe, returning number of bytes written, or -1 on error */
int write_to_pipe_formatted(int pipe_num, const char *format, ...)
{
    int status;
    if (!check_pipe_num(pipe_num))
        return -1;

    if (pipe_list[pipe_num].write_fd < 0)
      return -1;

    va_list args;
    va_start (args, format);
    status = vdprintf(pipe_list[pipe_num].write_fd, format, args);
    va_end (args);
    return status;
}


void write_data(pipe_buffer *bufr, char *data, int length)
{
    unsigned char *ptr;
    int offset;

    if (bufr->write_fd >= 0) {
        write(bufr->write_fd, data, length);

    } else if (bufr->stream_ptr != NULL) {
        ptr = bufr->stream_ptr;
	offset = bufr->stream_len;
	bufr->stream_len += length;
	if (bufr->stream_len <= bufr->stream_maxlen) {
	    /* Space available in buffer */
          memcpy(ptr+offset, data, length);
	}

    } else {
#ifdef DEBUG_FIFO
      fprintf(stderr, "FIFO:write_error: Writing to invalid pipe %d\n", bufr->pipe_num);
#endif
    }
}


/* Specify str = NULL and length = 0 to force flushing of buffer */

void append_to_line(pipe_buffer *bufr, char *str, int length)
{
    int i;

    i = 0;
    for (;;) {
        if (i < length)
            bufr->encoded_line[bufr->line_len++] = str[i++];

        if (bufr->line_len >= FIFO_LINEMAX || (!length && bufr->line_len)) {
            write_data(bufr, bufr->encoded_line, bufr->line_len);
	    if (bufr->encoding < 0)
	      write_data(bufr, "\n", 1);
            bufr->line_len = 0;
	}

        if (i >= length)
	  break;
    }
}


/* Base64 */

static char b64_encoding_table[] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
                                    'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
                                    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
                                    'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
                                    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
                                    'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
                                    'w', 'x', 'y', 'z', '0', '1', '2', '3',
                                    '4', '5', '6', '7', '8', '9', '+', '/'};

static int b64_mod_table[] = {0, 2, 1};

/* Write encoded data to buffer/file */
void write_encoded(int pipe_num, char *data, int length)
{
    char quad[4];
    int i, j, n_encoded;

    if (!check_pipe_num(pipe_num))
        return;

    pipe_buffer *bufr = &pipe_list[pipe_num];

    if (length || bufr->raw_len) {
        for (i = 0;;) {
            if (!length) {
	        /* Pad incomplete triple octet to finalize */
	        assert (bufr->raw_len < 3);
		n_encoded = 1 + (bufr->raw_len % 3);
		for (j=bufr->raw_len; j < 3; j++) {
		    bufr->raw_bytes[j] = 0;
		}
	    } else {
	        while (i < length && bufr->raw_len < 3) {
	            bufr->raw_bytes[bufr->raw_len++] = data[i++];
		}

                if (bufr->raw_len < 3)
		    break;
                n_encoded = 4;
	    }
            uint32_t octet_a = bufr->raw_bytes[0];
	    uint32_t octet_b = bufr->raw_bytes[1];
	    uint32_t octet_c = bufr->raw_bytes[2];

	    uint32_t triple = (octet_a << 0x10) + (octet_b << 0x08) + octet_c;

	    for (j=0; j < 4; j++) {
	        quad[j] = (j >= n_encoded) ? '=' : b64_encoding_table[(triple >> ((3-j)*6) ) & 0x3F];
	    }

	    append_to_line(bufr, quad, 4);

	    bufr->raw_len = 0;
	    if (i >= length)
	      break;
	}
    }

    if (!length)
        append_to_line(bufr, NULL, 0);	/* finalize */
    return;
}

int encode_image(int, char *, int, int, int, int *, int, int *, int);

/* Fortran-callable function that writes colormapped image data to supplied character buffer,
returning number of bytes written, or negative value in case of error.
img is a char(height, width) array with 0-255 colormap index values.
colors is a int(palette_size,3) array containing 0-255 RGB colormap triplets.
alphas is a int(n_alphas) array containing 0-255 alpha values (0=>transparent, 255=>opaque)
n_alphas must be <= 255, but is typically 0 or 1 for no or single transparent color.
(See allocate_file_pipe for meaning of encoding parameter)
If generated image data is more than out_bytes_max bytes, the negative of the required buffer size is returned as the error code.
A safe value for out_bytes_max would be 1500 + width*height. (Multiply by 1.33, if Base64 encoded)
*/

int render_image(char *img, int width, int height, char *outbuf, int out_bytes_max, int encoding,
  	         int reverse, int *colors, int palette_size, int *alphas, int n_alphas)
{
    int status = -1;
    int pipe_num;

#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:render_image: out_bytes_max, encoding, pointer outbuf: %d, %d, %ld\n", out_bytes_max, encoding, (unsigned long)outbuf);
#endif

    pipe_num = get_available_pipe();

    if (pipe_num < 0)
        return pipe_num;

    /* Initialize info for writing image stream to output buffer */
    pipe_list[pipe_num].encoding = encoding;
    pipe_list[pipe_num].stream_ptr = (unsigned char *)outbuf;
    pipe_list[pipe_num].stream_maxlen = out_bytes_max;

    status = encode_image(pipe_num, img, width, height, reverse, colors, palette_size, alphas, n_alphas);

    free_pipe(pipe_num);
    pipe_num = -1;

#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:render_image: return status = %d\n", status);
#endif

    return status;
}

/* Fortran-callable function that opens file/named-pipe(FIFO),
returning a file descriptor (>= 0) or negative value in case of error.
*/

int open_write_fd(const char *path, int named_pipe)
{
    int read_fd, write_fd, retval;
    struct stat pipe_status;

#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:open_write_fd: named_pipe, path: %d, %s\n", named_pipe, path);
#endif

    if (!named_pipe) {
        write_fd = open(path, O_WRONLY|O_CREAT, S_IRUSR|S_IWUSR);
        if (write_fd < 0) {
	    perror("FIFO:open_write_fd: read_fd: Failed to open file");
            return -1;
	}
    } else {
        signal(SIGPIPE, SIG_IGN);

	if (access(path, F_OK) != 0) {
	    retval = mkfifo(path, S_IRUSR|S_IWUSR);
	    if (retval < 0) {
	        perror("FIFO:open_write_fd: read_fd: Failed to create new named pipe (FIFO)");
		return -1;
	    }
	}

        read_fd = open(path, O_RDONLY | O_NONBLOCK);
        if (read_fd < 0) {
  	    perror("FIFO:open_write_fd: read_fd: Failed to open pipe");
            return -1;
        }

        if (fstat(read_fd, &pipe_status) < 0) {
            perror("FIFO:open_write_fd: read_fd: Failed fstat");
            close(read_fd);
            return -1;
        }

        if (!S_ISFIFO(pipe_status.st_mode)) {
            fprintf(stderr, "FIFO:open_write_fd: %s in not a named pipe! Remove it.\n", path);
            close(read_fd);
            return -1;
        }

#ifdef FIFO_BLOCKING
        write_fd = open(path, O_WRONLY);
#else
        write_fd = open(path, O_WRONLY | O_NONBLOCK);
#endif
        close(read_fd);

        if (write_fd < 0) {
	    perror("FIFO:open_write_fd: write_fd: Failed to open path");
            return -1;
        }
    }

#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:open_write_fd: return value %d\n", write_fd);
#endif
    return write_fd;
}

/* Fortran-callable function that initializes writing of colormapped image data to open file descriptor.
Returns pipe number (>= 0) on success or negative value on error
(See allocate_file_pipe for meaning of encoding parameter)
*/

int allocate_pipe(int write_fd, int encoding, int keep_open)
{
    int pipe_num;

    pipe_num = get_available_pipe();

    if (pipe_num < 0)
        return pipe_num;

    /* Initialize info for writing image stream to output buffer */
    pipe_list[pipe_num].write_fd = write_fd;
    pipe_list[pipe_num].keep_open = keep_open;
    pipe_list[pipe_num].encoding = encoding;

#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:allocate_pipe: write_fd, keep_open, encoding: %d, %d, %d\n", write_fd, keep_open, encoding);
#endif
    return pipe_num;
}

/* Fortran-callable function that opens a file/named-pipe(FIFO),
returning file descriptor number of file/named pipe or negative value in case of error.
A path value of "-" uses standard output.
encoding may be: NO_ENC        (0)  for none (raw bytes)
                 B64_ENC       (1)  for Base64
                 DATA_URL_ENC  (2)  for Base64 with data URL prefix+new line suffix (for fifofum.py)
                 B64_LINE_ENC  (-1) for Base64, broken into 80 character lines
                 GRAPHTERM_ENC (-2) for Base64 with GraphTerm prefix and suffix
If named_pipe, a FIFO file is opened (if needed) and kept open even after data is output.
*/

int allocate_file_pipe(const char *path, int encoding, int named_pipe)
{
  int write_fd, pipe_num, keep_open;

    if (path && strlen(path) == 1 && path[0] == '-') {
        write_fd = 1; /* stdout */
        keep_open = 1;
    } else {
        write_fd = open_write_fd(path, named_pipe);
	keep_open = named_pipe;
    }

    if (write_fd >= 0) {
        pipe_num = allocate_pipe(write_fd, encoding, keep_open);
    } else {
      pipe_num = write_fd;
    }
#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:allocate_file_pipe: path, named_pipe, return value: %s, %d, %d\n", path, named_pipe, pipe_num);
#endif
    return pipe_num;
}

#ifndef FIFO_NO_PNG
#include <png.h>

/* Specify data = NULL, length = 0 to force writing of incomplete triple octet */
void write_file(png_structp png_ptr, png_bytep data, png_uint_32 length)
{
    pipe_buffer *bufr;

    bufr = (pipe_buffer *) png_get_io_ptr(png_ptr);

    if (!bufr->encoding) {
        if (length)
          write_data(bufr, (char *) data, length);
	return;
    }

    write_encoded(bufr->pipe_num, (char *) data, length);
}

void flush_file(png_structp png_ptr)
{
    pipe_buffer *bufr = (pipe_buffer *) png_get_io_ptr(png_ptr);
    flush_pipe(bufr->pipe_num);
}
#endif

/* Fortran-callable function that writes colormapped image data to initialized file/pipe/character buffer.
img is a char(height, width) array with 0-255 colormap index values.
colors is a int(palette_size,3) array containing 0-255 RGB colormap triplets.
alphas is a int(n_alphas) array containing 0-255 alpha values (0=>transparent, 255=>opaque)
n_alphas must be <= 255, but is typically 0 or 1 for no or single transparent color.
Return number of characters converted on success, or negative value on error.
*/

int encode_image(int pipe_num, char *img, int width, int height, int reverse, int *colors, int palette_size,
	         int *alphas, int n_alphas)
{
    char width_height[4];
    char rgba[4*256];
    int p, x, y, offset3, offset4;

    int count = -1;
    int pixel_size = 1;
    int depth = 8;

    if (!check_pipe_num(pipe_num))
      return -1;

    for (p = 0; p < palette_size; p++) {
        offset3 = reverse ? 3*(palette_size-1-p) : 3*p;
	offset4 = 4*p;
	rgba[0+offset4] = colors[0+offset3];
	rgba[1+offset4] = colors[1+offset3];
	rgba[2+offset4] = colors[2+offset3];
	rgba[3+offset4] = (p < n_alphas) ? alphas[p] : 255;
    }
    for (p = palette_size; p < 256; p++) {
        offset4 = 4*p;
	rgba[0+offset4] = 0;
	rgba[1+offset4] = 0;
	rgba[2+offset4] = 0;
	rgba[3+offset4] = 0;
    }

#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:encode_image: pointers for img, colors, outbuf: %ld, %ld\n", (unsigned long) img, (unsigned long) colors);
    fprintf(stderr, "FIFO:encode_image: values for width, height, reverse, palette_size, n_alphas: %d, %d, %d, %d, %d\n", width, height, reverse, palette_size, n_alphas);
    fprintf(stderr, "FIFO:encode_image: R,G,B,A,img_0,img_n-1: (%d, %d, %d, %d) %d %d\n", rgba[0],rgba[1],rgba[2],rgba[3],img[0],img[width*height-1]);
#endif

    if (pipe_list[pipe_num].encoding == DATA_URL_ENC && strcmp(IMAGE_TYPE, "x-raw") == 0) {
	width_height[0] = width % 256;
	width_height[1] = width / 256;
	width_height[2] = height % 256;
	width_height[3] = height / 256;

        write_to_pipe_formatted(pipe_num, DATA_URL_PREFIX_FMT, IMAGE_TYPE);
	write_encoded(pipe_num, width_height, 4);
	write_encoded(pipe_num, rgba, 4*256);
	write_encoded(pipe_num, img, width*height);
	write_encoded(pipe_num, "", 0);
        write_to_pipe_formatted(pipe_num, "\n");
	flush_pipe(pipe_num);
        return 0;
    }

#ifndef FIFO_NO_PNG
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    png_bytep row = NULL;
    png_bytep trans_color = NULL;

    if (pipe_list[pipe_num].encoding == DATA_URL_ENC)
      write_to_pipe_formatted(pipe_num, DATA_URL_PREFIX_FMT, IMAGE_TYPE);
    if (pipe_list[pipe_num].encoding == GRAPHTERM_ENC)
        write_to_pipe_formatted(pipe_num, GRAPHTERM_PREFIX_FMT, IMAGE_TYPE);
    
    /* File info */
    png_ptr = png_create_write_struct (PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (png_ptr == NULL) {
        goto png_create_write_struct_failed;
    }

    /* Image info */
    info_ptr = png_create_info_struct (png_ptr);
    if (info_ptr == NULL) {
        goto png_create_info_struct_failed;
    }

    /* Set up error handling. */
    if (setjmp( png_jmpbuf(png_ptr) )) {
        goto png_failure;
    }

    /* Set image attributes. */
    png_set_IHDR (png_ptr,
                  info_ptr,
                  width,
                  height,
                  depth,
                  PNG_COLOR_TYPE_PALETTE,
                  PNG_INTERLACE_NONE,
                  PNG_COMPRESSION_TYPE_DEFAULT,
                  PNG_FILTER_TYPE_DEFAULT);

    png_color* palette = (png_color*) png_malloc(png_ptr, palette_size*sizeof(png_color));


    for (p = 0; p < palette_size; p++) {
        offset4 = 4*p;
	png_color* pcol = &palette[p];
        pcol->red   = rgba[0+offset4];
        pcol->green = rgba[1+offset4];
        pcol->blue  = rgba[2+offset4];
	/* fprintf(stderr, "COL=%d, offset4=%d: RGB (%d, %d, %d)\n", p, offset4, pcol->red, pcol->green, pcol->blue); */
    }

    png_set_PLTE(png_ptr, info_ptr, palette, palette_size);

    if (alphas != NULL && n_alphas > 0 && n_alphas <= 256) {
        /* Set up transparency block, starting from color index 0 */
        trans_color = (png_bytep) png_malloc(png_ptr, n_alphas * sizeof(png_byte));
	for (p = 0; p < n_alphas; p++) {
	  trans_color[p] = rgba[3+4*p];
	  /* fprintf(stderr, "ALPHA p=%d, alpha=%d\n", p, trans_color[p]); */ 
	}
	png_set_tRNS(png_ptr, info_ptr, (png_voidp) trans_color, n_alphas, NULL);
    }
  
    png_set_write_fn(png_ptr, (png_voidp) &pipe_list[pipe_num], (png_rw_ptr) write_file,
                    (png_flush_ptr) flush_file);

    png_write_info(png_ptr, info_ptr);

    /* Start writing image data */
    row = (png_bytep) png_malloc(png_ptr, pixel_size * width * sizeof(png_byte));

    for (y=0 ; y<height ; y++) {
        for (x=0 ; x<width ; x++) {
            row[x] = img[x+width*y];
	    /* fprintf(stderr, "IMG(%d,%d) = %d\n", y, x, row[x]); */
        }
        png_write_row(png_ptr, row);
    }

    /* End write */
    png_write_end(png_ptr, NULL);

    write_file(png_ptr, NULL, 0); /* Finalize */
    flush_pipe(pipe_num);

    png_free(png_ptr, row);

    if (pipe_list[pipe_num].encoding == DATA_URL_ENC)
        write_to_pipe_formatted(pipe_num, DATA_URL_SUFFIX);
    if (pipe_list[pipe_num].encoding == GRAPHTERM_ENC)
        write_to_pipe_formatted(pipe_num, GRAPHTERM_SUFFIX);

    if (pipe_list[pipe_num].stream_ptr) {
        if (pipe_list[pipe_num].stream_len <= pipe_list[pipe_num].stream_maxlen) {
	    count = pipe_list[pipe_num].stream_len; /* success! */
	} else {
	    count = -pipe_list[pipe_num].stream_len; /* buffer too small */
	}
    } else {
      count = 0;
    }

 png_failure:
 png_create_info_struct_failed:
    png_destroy_write_struct (&png_ptr, &info_ptr);
 png_create_write_struct_failed:
 /* End of FIFO_NO_PNG */
#endif
    return count;
}

/* Create and open named pipe for reading, returning file descriptor (>= 0) */
int open_read_fd(const char *path)
{
    int read_fd, retval;
    struct stat pipe_status;
 
    if (access(path, F_OK) != 0) {
        retval = mkfifo(path, S_IRUSR|S_IWUSR);
	if (retval < 0) {
	    perror("FIFO:open_read_fd: Failed to create new named pipe (FIFO)");
	    return -1;
	}
    }

    read_fd = open(path, O_RDONLY | O_NONBLOCK);
    if (read_fd < 0) {
      perror("FIFO:open_read_fd: Failed to open pipe for reading");
      return -1;
    }
    
    if (fstat(read_fd, &pipe_status) < 0) {
        perror("FIFO:open_read_fd: Failed fstat");
	close(read_fd);
	return -1;
    }

    if (!S_ISFIFO(pipe_status.st_mode)) {
        fprintf(stderr, "FIFO:open_read_fd: %s in not a named pipe! Remove it.\n", path);
	close(read_fd);
	return -1;
    }

#ifdef DEBUG_FIFO
    fprintf(stderr, "FIFO:open_read_fd: %d %s\n", read_fd, path);
#endif
    return read_fd;
}

/* Read upto count bytes from fd, returning number of bytes read, or -1 */
int read_from_fd(int fd, char *buf, int count)
{
  return read(fd, buf, count);
}


#ifdef TEST_MAIN

int main ()
{
    int read_fd, img_fd, b64_fd;
    int *img_colors;
    char *img_pixels;
    int p, x, y, x1, y1;
    char *out_bytes;
    int count;
    int max_bytes;
    int min_bytes = 1500;
    int ncolors = 256;
    int img_width = 100;
    int img_height = 100;
    char read_buf[FIFO_LINEMAX+1];
    char *readfile = "testin.fifo";
    char *imgfile = "testpng.png";
    char *b64file = "testpng.b64";
#ifdef TEST_STDOUT
    char *pipefile = "-";
#else
    char *pipefile = "testout.fifo";
#endif
    int pipe_num = -1;

    int reverse = 0;

    img_colors = malloc( sizeof(int) * 3 * ncolors);
    img_pixels = malloc( sizeof(char) * img_width * img_height);

    /* Create test palette of colors */
    for (p = 0; p < ncolors; p++) {
        int offset = 3*p;
        img_colors[0+offset] = p;
        img_colors[1+offset] = 100;
	img_colors[2+offset] = ncolors-p-1;
    }

    /* Create test image */
    for (y = 0; y < img_height; y++) {
        for (x = 0; x < img_width; x++) {
	  img_pixels[x+img_width*y] = y;
        }
    }

    max_bytes = img_width * img_height + min_bytes;
    max_bytes = 1 + (4*max_bytes)/3;   /* For Base64 encoding */

#ifndef FIFO_NO_PNG
    out_bytes = calloc(1, max_bytes);

    /* Create image */
    count = render_image(img_pixels, img_width, img_height, out_bytes, max_bytes, NO_ENC,
		         reverse, img_colors, ncolors, NULL, 0);
    if (count <= 0) {
        fprintf(stderr, "fifo_c: Error in creating PNG output file: %d\n", count);
        return -1;
    }

    img_fd = open(imgfile, O_WRONLY|O_CREAT, S_IRUSR|S_IWUSR);
    if (img_fd < 0) {
      fprintf(stderr, "fifo_c: Error: Failed to open image output file %s\n", imgfile);
      return -1;
    }
    write(img_fd, out_bytes, count);
    close(img_fd);

    free(out_bytes);

    fprintf(stderr, "fifo_c: Test PNG output file %s created (len=%d)\n", imgfile, count);

    b64_fd = open_write_fd(b64file, 0);
    if (b64_fd >= 0) {
        pipe_num = allocate_pipe(b64_fd, 1, 0);
	if (pipe_num >= 0) {
  	    count = encode_image(pipe_num, img_pixels, img_width, img_height, reverse, img_colors, ncolors, NULL, 0);
	    fprintf(stderr, "fifo_c: Base64 PNG output file %s created (%d)\n", b64file, count);
	    free_pipe(pipe_num);
  	    pipe_num = -1;
	}
    }
    /* End of FIFO_NO_PNG */
#endif

#ifdef TEST_GRAPHTERM
    pipe_num = allocate_file_pipe(pipefile, GRAPHTERM_ENC, 1);
#else
    pipe_num = allocate_file_pipe(pipefile, DATA_URL_ENC, 1);
#endif

    if (pipe_num >= 0) {
        read_fd = open_read_fd(readfile);
	if (read_fd < 0)
  	    return -1;
        fprintf(stderr, "fifo_c: Reading from named pipe %s\n", readfile);
        fprintf(stderr, "fifo_c: Writing to named pipe %s; Control-C to exit\n", pipefile);
	for (x1=0;;) {
  	    sleep(1);
	    count = read_from_fd(read_fd, read_buf, FIFO_LINEMAX+1);
	    if (count > 0) {
	        fprintf(stderr, "fifo_c: Read count=%d\n", count);
	        write(1, read_buf, count);
	    }
#ifndef TEST_GRAPHTERM
	    if (x1 > 25)
	      write_to_pipe_formatted(pipe_num, "channel:channel%d\n", 1 + x1 % 2);
	    write_to_pipe_formatted(pipe_num, "x=%d\n", x1);
#endif
	    encode_image(pipe_num, img_pixels, img_width, img_height, reverse, img_colors, ncolors, NULL, 0);
	    assert(img_height >= 10);
	    x1 = (x1 + 1) % img_width;           /* Animate moving pixels */
	    for (y1=(img_height/2)-2; y1<=(img_height/2)+2; y1++) {
  	        if (x1 != 0) {
		    img_pixels[x1+img_width*y1] = 255;
		} else {
		    for (x=0; x < img_width; x++)
		        img_pixels[x+img_width*y1] = y1;
		}
	    }
	}
	close(read_fd);
	free_pipe(pipe_num);
	pipe_num = -1;
    }

    free(img_colors);
    free(img_pixels);

    return 0;
}

#endif
