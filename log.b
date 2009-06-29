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

include "log.m";

stderr: ref Sys->FD;	
msgchan: chan of array of byte;	
REPOPATH: string;
	
init(ch: chan of array of byte, args: list of string, debug: int)
{
	sys = load Sys Sys->PATH;
	stringmodule = load String String->PATH;
	utils = load Utils Utils->PATH;

	REPOPATH = hd args; 
	utils->init(REPOPATH, debug);
	bufio = load Bufio Bufio->PATH;

	msgchan = ch;
	showlog(tl args);
}

showlog(commits: list of string)
{
	if(commits == nil){
		msgchan <-= nil;
		return;
	}
	sha1 := hd commits;
	commits = tl commits;

	(filetype, filesize, buf) := readsha1file(sha1);
	if(filetype != "commit")
		return showlog(commits);


	msgchan <-= sys->aprint("Commit: %s\n", sha1);

	ibuf := bufio->aopen(buf);

	#reading tree and throwing it away(maybe it can be used in the future).
	ibuf.gets('\n');


	while((s := ibuf.gets('\n')) != nil){
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
	msgchan <-= sys->aprint("%s\n", author);
	msgchan <-= sys->aprint("%s\n", committer);
	msgchan <-= sys->aprint("%s\n", comments);

	showlog(commits);
}

usage()
{
	sys->fprint(stderr, "log <commit-sha1>\n");
	return;
}
