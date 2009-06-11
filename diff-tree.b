implement Difftree;

include "sys.m";
	sys: Sys;
include "arg.m";
	arg: Arg;

include "draw.m";

include "utils.m";
	utils: Utils;
exists: import utils;

Difftree: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	utils = load Utils Utils->PATH;

	utils->init();

	if(len args != 3 || !exists(args[1] || !exists(arg[2])))
	{
		usage();
		return;
	}
	
	difftree(hd (tl args), (hd (tl (tl args))));
}


difftree(tree1, tree2: string)
{
	(filetype1, filesize1, buf1) := readsha1file(tree1);		
	(filetype2, filesize2, buf2) := readsha1file(tree2);
	if(filetype1 != "tree" || filetype1 != filetype2)
{
		usage();
		return;
	}
	
}

usage()
{
	sys->fprint(stderr, "usage: diff-tree <tree-sha1> <tree-sha2>\n");
	return;
}

