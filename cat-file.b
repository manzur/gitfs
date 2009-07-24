implement Catfile;

	
include "gitfs.m";
include "mods.m";

mods: Mods;
include "modules.m";

bytepos, sha2string, SHALEN: import utils;	

printtypeonly := 0;

init(m: Mods)
{
	mods = m;
}

catfile(path: string, msgchan: chan of array of byte)
{
	(filetype, nil, buf) := utils->readsha1file(path);	

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

