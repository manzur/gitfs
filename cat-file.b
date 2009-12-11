implement Catfile;

include "gitfs.m";
include "mods.m";

mods: Mods;
include "modules.m";

sprint: import sys;
bytepos, sha2string, SHALEN: import utils;	

printtypeonly := 0;

init(m: Mods)
{
	mods = m;
}

catfile(sha1: string, msgchan: chan of array of byte)
{
	str := ""; offset := 0;
	(filetype, nil, buf) := utils->readsha1file(sha1);	
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
