implement Log;

include "sys.m";
	sys: Sys;

include "draw.m";	

include "tables.m";
Strhash: import Tables;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;	

include "utils.m";
	utils: Utils;
exists, chomp, readsha1file: import utils;	

include "string.m";
	stringmodule: String;
splitr: import stringmodule;	

stderr: ref Sys->FD;	
	
Log: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	utils = load Utils Utils->PATH;
	stringmodule = load String String->PATH;
	bufio = load Bufio Bufio->PATH;
	utils->init();

	stderr = sys->fildes(2);

	if(len args != 2 || !exists(hd (tl args)))
	{
		usage();
		return;
	}
	
	showlog(tl args);
	
}

showlog(commits: list of string)
{
	if(commits == nil)
		return;
	sha1 := hd commits;
	commits = tl commits;

	(filetype, filesize, buf) := readsha1file(sha1);
	sys->print("filetype %s; filesize: %d\n",filetype, filesize);
	if(filetype != "commit")
	{
		sys->print("%s is not commit\n", sha1);
		return showlog(commits);
	}
	sys->print("Commit: %s\n", sha1);
	ibuf := bufio->aopen(buf);

	#reading tree and throwing it away(maybe it can be used in the future).
	ibuf.gets('\n');

	while((s := ibuf.gets('\n')) != nil)
	{
		(t, parentsha1) := splitr(s, " ");
		if(t != "parent ")
			break;
		parentsha1 = chomp(parentsha1);
		commits = parentsha1 :: commits;
	}
	author := chomp(s);
	committer := ibuf.gets('\n');
	ibuf.gets('\n');
	comments := ibuf.gets('\0');
	sys->print("%s\n", author);
	sys->print("%s\n", comments);

	showlog(commits);
}

usage()
{
	sys->fprint(stderr, "log <commit-sha1>\n");
	return;
}
