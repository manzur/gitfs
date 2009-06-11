#include <zlib.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <assert.h>

int main()
{
	mydeflate();
	return 0;
	
}

int mydeflate()
{
#define CHUNK 16384
    int ret, flush;
    unsigned have;
    z_stream strm;
    unsigned char in[CHUNK];
    unsigned char out[CHUNK];
    const char* in_file = "text";
    const char* out_file = "mytext.zip";
    FILE* source = fopen(in_file, "r");
    FILE* dest = fopen(out_file, "w+");

    /* allocate deflate state */
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    int level = 6;
    ret = deflateInit(&strm, level);
    if (ret != Z_OK)
        return ret;

    /* compress until end of file */
    do {
        strm.avail_in = fread(in, 1, CHUNK, source);
        if (ferror(source)) {
            (void)deflateEnd(&strm);
	    fprintf(stderr, "ferror in source\n");
            return Z_ERRNO;
        }
        flush = feof(source) ? Z_FINISH : Z_NO_FLUSH;
        strm.next_in = in;

        /* run deflate() on input until output buffer not full, finish
           compression if all of source has been read in */
        do {
            strm.avail_out = CHUNK;
            strm.next_out = out;
            ret = deflate(&strm, flush);    /* no bad return value */
            assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
            have = CHUNK - strm.avail_out;
            if (fwrite(out, 1, have, dest) != have || ferror(dest)) {
                (void)deflateEnd(&strm);
		fprintf(stderr, "error in fwrite\n");
                return Z_ERRNO;
            }
        } while (strm.avail_out == 0);
        assert(strm.avail_in == 0);     /* all input will be used */

        /* done when last data in file processed */
    } while (flush != Z_FINISH);
    assert(ret == Z_STREAM_END);        /* stream will be complete */

    /* clean up and return */
    (void)deflateEnd(&strm);
    return Z_OK;


}

int myinflate()
{
	const char* in_file = "text.zip";
	const char* out_file = "text.out";
	int ifd = open(in_file, O_RDONLY);
	int ofd = open(out_file, O_WRONLY | O_CREAT);
	z_stream strm;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.avail_in = 0;
	strm.next_in = Z_NULL;
	int ret = inflateInit(&strm);
	if(ret != Z_OK)
	{
		fprintf(stderr, "error in  init\n");
		return 1;
	}
#define BUFSZ 512
	char buf[BUFSZ];
	do
	{
		int cnt = read(ifd, buf, BUFSZ);
		if(cnt == 0)
		{
			break;
		}
		strm.avail_in = cnt;
		strm.next_in = buf;
		do
		{
			char out[BUFSZ];
			strm.avail_out = BUFSZ;
			strm.next_out = out;
			ret = inflate(&strm,Z_NO_FLUSH);		
			assert(ret != Z_STREAM_ERROR);

			switch(ret)
			{
				case Z_MEM_ERROR:
				case Z_NEED_DICT:
				case Z_DATA_ERROR:
					inflateEnd(&strm);
					fprintf(stderr, "some error after inflate\n");
					return 2;
			}
			int have = BUFSZ - strm.avail_out;
			if(write(ofd, out, have) != have)
			{
				fprintf(stderr, "error in outputing\n");
				return 3;
			}
			

		}while(strm.avail_out == 0);
		
	}while(ret != Z_STREAM_END);

	close(ifd);
	close(ofd);

}
