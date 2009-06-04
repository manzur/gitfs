implement Readtree;

include "sys.m";
	sys: Sys;

include "draw.m";

include "utils.m";
	utils: Utils;


readsha1file: import utils;

Readtree: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};


init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;	
	utils = load Utils Utils->PATH;
	utils->init();
	if(len args != 2)
		usage();
	readtree(hd (tl args));
}

readtree(path: string)
{
	(filetype, filesize, buf) := readsha1file(path);
	
	sys->print("File type: %s\n", filetype);
	sys->print("File size: %d\n", filesize);
	offset := 0;
	fd := sys->fildes(1);
	while(offset != len buf)
	{
		offset += sys->write(fd, buf, len buf - offset);
	}
}

usage()
{
	sys->fprint(sys->fildes(2), "usage: read-tree <tree-sha>\n");
}

