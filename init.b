implement Initgit;

include "init.m";

include "sys.m";

include "draw.m";

include "keyring.m";

include "tables.m";
Strhash: import Tables;

include "gitindex.m";
	gitindex: Gitindex;
Header, Index, HEADERSZ: import gitindex;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;	

include "utils.m";
INDEXPATH, OBJECTSTOREPATH, SHALEN: import Utils;


REPOPATH: string;

init(args: list of string, debug: int)
{
	sys := load Sys Sys->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	keyring := load Keyring Keyring->PATH;

	stderr := sys->fildes(2);

	REPOPATH = hd args;
	sys->print("Initializing git repo\n");

#FIXME: Replace "" with MNTPT
	Index.new(REPOPATH, "",debug);

	header := Header.new();
	temp := header.unpack()[:HEADERSZ - SHALEN];
	
	keyring->sha1(temp, len temp, header.sha1, nil);
	
	if((fd := sys->create(REPOPATH + INDEXPATH, Sys->OWRITE, 8r644)) == nil ||
	   sys->write(fd, temp, len temp) != len temp ||
	   sys->write(fd, header.sha1, SHALEN) != SHALEN)
	{
		sys->fprint(stderr,"error in creating index file: %r\n");
		return;
	}

	if(sys->create(REPOPATH + OBJECTSTOREPATH, Sys->OREAD, Sys->DMDIR | 8r700) == nil)
	{
		sys->fprint(stderr, "objects dir couldn't be created: %r\n");
		return;
	}

	for(i := 0; i <= 255; i++)
	{
		dirname := sys->sprint("%sobjects/%02x", REPOPATH, i);
		dirfd := sys->create(dirname,Sys->OREAD,sys->DMDIR | 8r700);
		if(dirfd == nil)
			sys->fprint(stderr, "directory %s/%s couldn't be created: %r\n", OBJECTSTOREPATH, dirname);
	}

	sys->print("Initialization's finished\n");
}

