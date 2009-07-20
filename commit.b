implement Commitmod;

include "sys.m";
	sys: Sys;
sprint: import sys;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;	

include "daytime.m";
	daytime: Daytime;
gmt, Tm: import daytime;	

include "lists.m";
	lists: Lists;
	
include "string.m";
	stringmod: String;

include "tables.m";
	tables: Tables;
Strhash: import tables;	

include "utils.m";
	utils: Utils;
error, ltrim, readsha1file: import utils;	

include "commit.m";

init(arglist: list of string, debug: int)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	daytime = load Daytime Daytime->PATH;
	lists = load Lists Lists->PATH;
	stringmod = load String String->PATH;
	tables = load Tables Tables->PATH;	

	utils = load Utils Utils->PATH;
	utils->init(arglist, debug);
}

parsedate(date: string): ref Tm
{
	while(date != nil && date[0] == ' ')
		date = date[1:];
	(tim, zone) := stringmod->toint(date, 10);
	tm := gmt(tim);
	
	zone = ltrim(zone);
	sign := 1;

	if(zone[0] == '-')
		sign = -1;

	sign = zone[0];
	zone = zone[1:];
	
	offset := stringmod->toint(zone[:2], 10).t0 * 60 + stringmod->toint(zone[2:4], 10).t0;
	
	tm.tzoff = sign * offset;

	return tm;
}

readcommit(sha1: string): ref Commit
{
	(filetype, filesize, filebuf) := readsha1file(sha1);
	if(filetype != "commit"){
		error(sprint("File %s isn't commit type\n", sha1));
		return nil;
	}

	return readcommitbuf(sha1, filebuf);
}

readcommitbuf(sha1: string, filebuf: array of byte): ref Commit
{
	ibuf := bufio->aopen(filebuf);

	s := ibuf.gets('\n');
	(type1, treesha1) := stringmod->splitl(s, " ");
	if(type1 != "tree"){
		error("File %s is corrupted\n");
		return nil;
	}
	treesha1 = treesha1[1:len treesha1 - 1];

	parents: list of string;
	while((s = ibuf.gets('\n')) != ""){
		(tag, parentsha1) := stringmod->splitl(s, " ");
		if(tag == "author") break;
		parentsha1 = parentsha1[1:len parentsha1 - 1];
		parents = parentsha1 :: parents;
	}
	author := s[:len s - 1];
	s = ibuf.gets('\n');
	committer := s[:len s - 1];
	
	(nil, s) = stringmod->splitr(committer, ">");
	date := parsedate(s);

#FIXME: write code for reading encoding
	comment := ibuf.gets('\0');

	return ref Commit(sha1, treesha1, lists->reverse(parents), author, committer, nil, date, comment);
}


