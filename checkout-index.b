implement Checkoutindex;

include "checkout-index.m";

include "sys.m";
	sys: Sys;
sprint: import sys;

include "tables.m";
	tables: Tables;
Strhash: import tables;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;	

include "gitindex.m";
	gitindex: Gitindex;
Index, Entry: import gitindex;	

include "utils.m";
	utils: Utils;
debugmsg, error, INDEXPATH, sha2string,string2path, readsha1file: import utils;	

include "arg.m";
	arg: Arg;

index: ref Index;
all: int = 0;
force: int = 0;
REPOPATH: string;

init(args: list of string, debug: int)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	gitindex = load Gitindex Gitindex->PATH;
	tables = load Tables Tables->PATH;
	utils = load Utils Utils->PATH;

	REPOPATH = hd args;

	utils->init(REPOPATH, debug);
	index = Index.new(REPOPATH, debug);
	if(!index.readindex(INDEXPATH))
	{
		error("index read error\n");
		exit;
	}
	
	arg->init(args);
	while((c := arg->opt()) != 0){
		case c
		{
			'a' => all = 1;
			'f' => force = 1;
		}
	}
	args = arg->argv();
	if(all)
		checkoutall();
	else if(args != nil)
	{
		while(args != nil)	
		{
			checkoutfile(hd args);
			args = tl args;
		}
		return;
	}
}


checkoutfile(path: string)
{
	fullpath := REPOPATH + path;
	entry := index.entries.find(path);
	if(entry == nil){
		error(sprint("No such file: %s\n", path));
		return;
	}
	#if file exists and force flag is off
	if(!force && sys->open(fullpath, Sys->OREAD) != nil){
		error(sprint("file(%s) exists\n", path));
		return;
	}
	fd := sys->create(fullpath, Sys->OWRITE, 8r644);
	if(fd == nil){
		makedirs(dirname(fullpath));
		fd = sys->create(fullpath, Sys->OWRITE, 8r644);
		if(fd == nil){
			error(sprint("file(%s) couldn't be created\n", path));
			return;
		}
	}
	checkoutentry(fd, entry);
}

checkoutentry(fd: ref Sys->FD, entry: ref Entry)
{
	(filetype, filesize, buf) := readsha1file(sha2string(entry.sha1));
	debugmsg(sprint("filetype: %s; filesize: %d\n", filetype, filesize));
	if(sys->write(fd, buf, len buf) != len buf){
		error(sprint("error occured while writing to file: %r\n"));
		return;
	}
	dirstat := sys->nulldir;
	dirstat.mode = entry.mode & 1023;
	if(sys->fwstat(fd, dirstat)){
		error(sprint("stat can't be changed: %r\n"));
		return;
	}
}


checkoutall()
{
	for(l := index.entries.all(); l != nil; l = tl l)
	{
		debugmsg(sprint("checking out: %s\n", (hd l).name));
		checkoutfile((hd l).name);
	}
}

dirname(path: string): string
{
	for(i := len path - 1; i >= 0; i--){
		if(path[i] == '/')
			return path[0:i];
	}
	return ".";
}

makedirs(path: string)
{
	if(!exists(path))
		makedirs(dirname(path));
	sys->create(path, Sys->OREAD,  Sys->DMDIR|8r755);

}

exists(path: string): int
{
	(ret, nil) := sys->stat(path);
	return ret != -1;
}


