#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <openssl/sha.h>

#define HDRSZ (sizeof(0) * 3)
#define ENTRYSZ (40)
#define GITENTRYSZ (62)
#define SHALEN (20)

void convert();
void freemem();
char *sha1_to_hex(const unsigned char *sha1);
char* sha1_to_path(char* sha1);

SHA_CTX ctx;

char *cwd, *name, *iname, *oname, *path, *repopath;
void *entry, *header;  

int main(int argc, char **argv)
{
	cwd = repopath = get_current_dir_name();
	if(argc == 2){
		repopath = argv[1];
	}

	atexit(freemem);
	
	if(access(repopath, F_OK)){
		usage();
	}
	
	convert();

	return 0;
}



void convert()
{
	int repolen = strlen(repopath);
	iname = malloc(repolen + strlen("/.git/gitfsindex"));
	oname = malloc(repolen + strlen("/.git/index"));
	strcpy(iname, repopath);
	strcpy(oname, repopath);
	strcpy(iname + repolen, "/.git/gitfsindex");
	strcpy(oname + repolen, "/.git/index");

	SHA1_Init(&ctx);
	printf("path:%s\n", iname);
	printf("path:%s\n", oname);
	FILE* ifd = fopen(iname, "r");
	FILE* ofd = fopen(oname, "w+");
	if(!ifd || !ofd){
		perror("error at opening files");
		exit(1);
	}

	/* Skipping sha1 of the index file */
	fseek(ifd, 20l, SEEK_SET);
	header = malloc(HDRSZ);
	if(fread(header, HDRSZ, 1, ifd) != 1){
		perror("index read error");
		exit(1);
	}
	
	int entriescnt = write_header(ofd, header);
	printf("entriescnt: %d\n", entriescnt);
	entry = malloc(ENTRYSZ);
	int i;
	for(i = 0; i < entriescnt; i++){
		fread(entry, ENTRYSZ, 1, ifd);
		const unsigned char *sha1 = entry + 16;
		int flags = ntohl(*(int*)(sha1 + SHALEN));
		int namelen = flags & 0x0fff;
		printf("namelen %d\n", namelen);
		name = malloc(namelen + 1);
		fread(name, namelen, 1, ifd);
		write_entry(ofd, name, namelen, sha1);
		free(name);
		name = 0;
	}
	char sha1[20];
	SHA1_Final(sha1, &ctx);
	fwrite(sha1, 20, 1, ofd);

	fclose(ifd);
	fclose(ofd);
}

void freemem()
{
	if(cwd)	free(cwd);
	if(header) free(header);
	if(iname) free(iname);
	if(entry) free(entry);
	if(name) free(name);
	if(oname) free(oname);
	if(path) free(path);
}

void htonst(struct stat* st)
{
	st->st_dev = htonl(st->st_dev);
	st->st_ino = htonl(st->st_ino);
	st->st_mode = htonl(st->st_mode);
	st->st_uid = htonl(st->st_uid);
	st->st_gid = htonl(st->st_gid);
	st->st_mtime = htonl(st->st_mtime);
	st->st_ctime = htonl(st->st_ctime);
	st->st_size = htonl(st->st_size);
}

write_entry(FILE* ofd, char* name, int namelen, const char* sha1)
{
	printf("name %s\n", name);
	struct stat st;
	path = sha1_to_path(sha1_to_hex(sha1));
	if(stat(path, &st) == -1){
		printf("sha1 is %s\n", path);
		perror("sha1(%s) stat error");
		exit(1);
	}
	free(path);
	path = 0;

	printf("ino:%ld\n", (long)st.st_ino);
	printf("size: %d\n", (int)st.st_size);

	int nsec = 0;
	
	htonst(&st);

	SHA1_Update(&ctx, &st.st_ctime, sizeof st.st_ctime);
	fwrite(&st.st_ctime, sizeof st.st_ctime, 1, ofd);

	SHA1_Update(&ctx, &nsec, sizeof nsec);
	fwrite(&nsec, sizeof nsec, 1, ofd);

	SHA1_Update(&ctx, &st.st_mtime, sizeof st.st_mtime);
	fwrite(&st.st_mtime, sizeof st.st_mtime, 1, ofd);

	SHA1_Update(&ctx, &nsec, sizeof nsec);
	fwrite(&nsec, sizeof nsec, 1, ofd);

	unsigned int dev = st.st_dev;
	SHA1_Update(&ctx, &dev, sizeof dev);
	fwrite(&dev, sizeof dev, 1, ofd);

	printf("dev is: %u\n", dev);

	unsigned int ino = st.st_ino;
	SHA1_Update(&ctx, &ino, sizeof ino);
	fwrite(&ino, sizeof ino, 1, ofd);

	printf("ino is: %u\n", (unsigned)st.st_ino);

	SHA1_Update(&ctx, &st.st_mode, sizeof st.st_mode);
	fwrite(&st.st_mode, sizeof st.st_mode, 1, ofd);

	SHA1_Update(&ctx, &st.st_uid, sizeof st.st_uid);
	fwrite(&st.st_uid, sizeof st.st_uid, 1, ofd);

	printf("uid is: %u\n", st.st_uid);

	SHA1_Update(&ctx, &st.st_gid, sizeof st.st_gid);
	fwrite(&st.st_gid, sizeof st.st_gid, 1, ofd);

	SHA1_Update(&ctx, &st.st_size, sizeof st.st_size);
	fwrite(&st.st_size, sizeof st.st_size, 1, ofd);

	SHA1_Update(&ctx, sha1, SHALEN);
	fwrite(sha1, SHALEN, 1, ofd);

/*FIXME: namelen should be changed to flags */
	short flags = htons((short)namelen);
	SHA1_Update(&ctx, &flags, 2);
	fwrite(&flags, 2, 1, ofd);

	SHA1_Update(&ctx, name, namelen);
	fwrite(name, namelen, 1, ofd);

	align(ofd, namelen);
}

int write_header(FILE* ofd, void* header)
{
	int signature = ntohl(*(int*)(header));
	int version = ntohl(*(int*)(header + sizeof(0)));
	int entriescnt = ntohl(*(int*)(header + sizeof(0) * 2));
//	*(int*)header = signature;	
//	*(int*)(header + sizeof(0)) = htonl(version);	
//	*(int*)(header + sizeof(0)*2) = htonl(entriescnt);	
	
	printf("sig: %d, ver: %d, cnt: %d\n", signature, version, entriescnt);
	SHA1_Update(&ctx, header, HDRSZ);
	if(fwrite(header, HDRSZ, 1, ofd) != 1){
		perror("index write error");
		exit(1);
	}

	return entriescnt;
}

align(FILE* ofd, int namelen)
{
/*FIXME: add processing for extended cache_entry*/
	int len = ((namelen + GITENTRYSZ + 8) & ~7) - GITENTRYSZ - namelen;
	void* garbage = malloc(len);
	SHA1_Update(&ctx, garbage, len);
	fwrite(garbage, len, 1, ofd);	
	free(garbage);
}

/* Returned path should be freed after being used */
char* sha1_to_path(char* sha1)
{
	char* gitpath = "/.git/objects/";
	int glen = strlen(gitpath);
	int repolen = strlen(repopath);

	char* path = malloc(repolen + glen + 40 + 2);
	strcpy(path, repopath);
	strcpy(path+repolen, gitpath);

	int offset = repolen + glen;
	path[offset++] = sha1[0];
	path[offset++] = sha1[1];
	path[offset++] = '/';
	strncpy(path + offset, sha1 + 2, 38);

	return path;
}


char* sha1_to_hex(const unsigned char *sha1)
{
	static int bufno;
	static char hexbuffer[4][50];
	static const char hex[] = "0123456789abcdef";
	char *buffer = hexbuffer[3 & ++bufno], *buf = buffer;
	int i;

	for (i = 0; i < 20; i++) {
		unsigned int val = *sha1++;
		*buf++ = hex[val >> 4];
		*buf++ = hex[val & 0xf];
	}
	*buf = '\0';

	return buffer;
}

usage()
{
	fprintf(stderr, "translator <path_to_repo>\n");
	exit(1);
}
