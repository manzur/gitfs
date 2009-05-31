implement Initgit;

include "sys.m";

include "draw.m";

include "keyring.m";

include "tables.m";

Strhash: import Tables;

include "gitindex.m";
	gitindex: Gitindex;

Header: import gitindex;


Initgit: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};


init(nil: ref Draw->Context, args: list of string)
{
	sys := load Sys Sys->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	keyring := load Keyring Keyring->PATH;

	sys->print("Initing git repo\n");

	header: gitindex->Header;
	header.signature = gitindex->CACHESIGNATURE;
	header.version = 1;
	header.entriescnt = 0;
	header.sha1 = array[gitindex->SHALEN] of byte;
	newheader := ref header;
	temp := newheader.unpack()[:gitindex->HEADERSZ - gitindex->SHALEN];
	
	keyring->sha1(temp, len temp, header.sha1, nil);
	
	fd: ref Sys->FD;

	if((fd = sys->create("index", Sys->OWRITE, 644)) == nil ||
	   sys->write(fd, temp, len temp) != len temp ||
	   sys->write(fd, header.sha1, gitindex->SHALEN) != gitindex->SHALEN)
	{
		sys->print("error in creating index file: %r\n");
		return;
	}

	sys->print("Init finish\n");
}
