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
bytepos, sha2string, SHALEN: import utils;	
	
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

	msgchan <-= sys->aprint("filetype: %s\n", filetype);
	if(printtypeonly){
		msgchan <-= nil;
		return;
	}
	str := "";
	offset := 0;
	while(filetype == "tree" && (pos := bytepos(buf, offset, byte 0)) != -1){
		pos++;
		sha1 := buf[pos: pos + SHALEN];
		str += string buf[offset: pos - 1];
		str += " " + sha2string(sha1);
		offset = pos + SHALEN;
	}
	if(filetype == "tree")
		msgchan <-= sys->aprint("%s", str);
	else
		msgchan <-= buf[:];
}

usage()
{
	sys->fprint(sys->fildes(2), "usage: cat-file <sha1>");
	exit;
}

