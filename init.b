implement Initgit;

include "sys.m";

include "draw.m";

include "keyring.m";

include "tables.m";

Strhash: import Tables;

include "gitindex.m";
	gitindex: Gitindex;
Header, Index, HEADERSZ: import gitindex;

include "utils.m";
INDEXPATH, OBJECTSTOREPATH, SHALEN: import Utils;



Initgit: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};


init(nil: ref Draw->Context, args: list of string)
{
	sys := load Sys Sys->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	keyring := load Keyring Keyring->PATH;

	stderr := sys->fildes(2);

	sys->print("Initializing git repo\n");

	Index.new();

	header := Header.new();
	temp := header.unpack()[:HEADERSZ - SHALEN];
	
	keyring->sha1(temp, len temp, header.sha1, nil);
	
	if((fd := sys->create(INDEXPATH, Sys->OWRITE, 8r644)) == nil ||
	   sys->write(fd, temp, len temp) != len temp ||
	   sys->write(fd, header.sha1, SHALEN) != SHALEN)
	{
		sys->fprint(stderr,"error in creating index file: %r\n");
		return;
	}

	if(sys->create(OBJECTSTOREPATH, Sys->OREAD, Sys->DMDIR | 8r700) == nil)
	{
		sys->fprint(stderr, "objects dir couldn't be created: %r\n");
		return;
	}

	for(i := 0; i <= 255; i++)
	{
		dirname := sys->sprint("objects/%02x", i);
		dirfd := sys->create(dirname,Sys->OREAD,sys->DMDIR | 8r700);
		if(dirfd == nil)
			sys->fprint(stderr, "directory %s/%s couldn't be created: %r\n", OBJECTSTOREPATH, dirname);
	}

	sys->print("Initialization's finished\n");
}

