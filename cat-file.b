implement Catfile;

include "sys.m";
	sys: Sys;

include "tables.m";
	tables: Tables;
Strhash: import tables;	

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;		
	
include "utils.m";
	utils: Utils;
	
include "cat-file.m";

msgchan: chan of array of byte;
printtypeonly := 0;
REPOPATH: string;

init(repopath: string, typeonly: int, path: string, ch: chan of array of byte)
{
	sys = load Sys Sys->PATH;
	utils = load Utils Utils->PATH;

	REPOPATH = repopath;
	utils->init(repopath);
       
	printtypeonly = typeonly;
	msgchan = ch;
	catfile(path);
}

catfile(path: string)
{
	(filetype, filesize, buf) := utils->readsha1file(path);	
	offset := 0;

	msgchan <-= sys->aprint("filetype: %s\n", filetype);
	if(printtypeonly){
		msgchan <-= nil;
		return;
	}
	msgchan <-= buf[offset:];
}

usage()
{
	sys->fprint(sys->fildes(2), "usage: cat-file <sha1>");
	exit;
}

