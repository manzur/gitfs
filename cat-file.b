implement Catfile;

include "sys.m";
	sys: Sys;

include "bufio.m";
Iobuf: import Bufio;		

include "tables.m";
Strhash: import Tables;	

include "utils.m";
	utils: Utils;
bytepos, sha2string, SHALEN: import utils;	
	
include "cat-file.m";

msgchan: chan of array of byte;
printtypeonly := 0;
repopath: string;

init(arglist: list of string, ch: chan of array of byte, debug: int)
{
	sys = load Sys Sys->PATH;
	utils = load Utils Utils->PATH;

	utils->init(arglist,  debug);

	repopath = hd arglist;
	arglist = tl tl arglist;
	path := hd arglist; 

#FIXME: use it or remove
#	printtypeonly = typeonly;
	msgchan = ch;
	catfile(path);
}

catfile(path: string)
{
	(filetype, nil, buf) := utils->readsha1file(path);	

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

