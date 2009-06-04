implement Catfile;

include "sys.m";
	sys: Sys;

include "draw.m";

include "utils.m";
	utils: Utils;
	

Catfile: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};


init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	if(len args != 2)
	{
		usage();
		return;
	}
	utils = load Utils Utils->PATH;
	utils->init();
	catfile(hd (tl args));
}


catfile(path: string)
{
	(filetype, filesize, buf) := utils->readsha1file(path);	
	offset := 0;
	sys->print("filetype: %s\n", filetype);
	while(offset < len buf)
	{
		cnt := sys->write(sys->fildes(1), buf[offset:], len buf - offset);
		offset += cnt;
	}
}

usage()
{
	sys->fprint(sys->fildes(2), "usage: cat-file <sha1>");
	return;
}

