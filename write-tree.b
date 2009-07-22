implement Writetree;

include "write-tree.m";

include "sys.m";
	sys: Sys;
sprint: import sys;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "filter.m";
	deflate: Filter;

include "string.m";
	stringmod: String;

include "tables.m";
	tables: Tables;
Strhash: import tables;

include "gitindex.m";
	gitindex: Gitindex;
Index, Entry: import gitindex;

include "utils.m";
	utils: Utils;
bufsha1, sha2string, SHALEN: import utils;

index: ref Index;
repopath: string;
debug: int;

init(arglist: list of string, deb: int)
{
	sys = load Sys Sys->PATH;

	deflate = load Filter Filter->DEFLATEPATH;
	stringmod = load String String->PATH;
	tables = load Tables Tables->PATH;

	gitindex = load Gitindex Gitindex->PATH;
	utils = load Utils Utils->PATH;

	debug = deb;
	repopath = hd arglist;

	deflate->init();
	utils->init(arglist, debug);
}

writetree(index: ref Index): string
{
	l := mergesort(index.entries.all());
	return sha2string(writetreefile(l, "").t0);
}

writetreefile(entrylist: list of ref Entry, basename: string): (array of byte, list of ref Entry)
{
	offset := 0;
	filelist := array[Sys->ATOMICIO] of byte;
	while(entrylist != nil)
	{
		entry := hd entrylist;
		if(!stringmod->prefix(basename, entry.name))
			break;

		sha1 := entry.sha1;
		name := entry.name;

		#32768 - flag for indicating regular file in Linux
		mode := 8r644 | 32768;

		rest: string;
		(name, rest) = stringmod->splitl(name[len basename:], "/");
		if(rest != "")
		{
			(sha1, entrylist) = writetreefile(entrylist, basename + name + "/");
			#turning on flag for the dir mode
			mode = 8r755 | 16384;
		}

		record := sys->aprint("%o %s", mode, name);
		temp := array[len record + 1 + SHALEN] of byte;
		temp[:] = record;
		temp[len record] = byte 0;
		temp[len record + 1:] = sha1;
		if(len temp + offset >= len filelist)
		{
			oldfilelist := filelist;
			filelist = array[len oldfilelist * 2] of byte;
			filelist[:] = oldfilelist;
		}
		filelist[offset:] = temp;
		offset += len temp;
		if(entrylist != nil)
			entrylist = tl entrylist;
	}

	header := sys->aprint("tree %bd", big offset);
#	header := sys->aprint("tree %bd", big 0);
	

#	#+1 is for 0 byte,which is used as a separator
	buf := array[len header + offset + 1] of byte;
	buf[:] = header[:];
	buf[len header] = byte 0;
	buf[len header + 1:] = filelist[:offset];

	ch := chan of (int, array of byte);
	spawn utils->writesha1file(ch);
	sha: array of byte;
	sz: int;
	ch <-= (len buf, buf);
	ch <-= (0, nil);
	(sz, sha) = <-ch;


	sys->print("tree is written to %s\n", sha2string(sha));
	return (sha, entrylist);
}

mergesort(l: list of ref Entry): list of ref Entry
{
	if(len l > 1)
	{
		middle := len l / 2;
		(l1, l2) := partitionbypos(l, middle);
		l1 = mergesort(l1);
		l2 = mergesort(l2);
		return merge(l1, l2);
	}
	return l;
}

merge(l1, l2: list of ref Entry): list of ref Entry
{
	if(l1 == nil)
		return l2;
	if(l2 == nil)
		return l1;
	
	l: list of ref Entry = nil;
	while(l1 != nil && l2 != nil)
	{
		if((hd l1).compare(hd l2) == 1)
		{
			l = hd l1 :: l;
			l1 = tl l1;
			continue;
		}
		l = hd l2 :: l;
		l2 = tl l2;
	}

	while(l1 != nil)
	{
		l = hd l1 :: l;
		l1 = tl l1;
	}

	while(l2 != nil)
	{
		l = hd l2 :: l;
		l2 = tl l2;
	}

	l = reverse(l);
	return l;
}

partitionbypos(l: list of ref Entry, pos: int): (list of ref Entry, list of ref Entry)
{
	if(len l < pos)
		return (l, nil);
	l1 : list of ref Entry = nil;
	for(i := 0; i < pos; i++)
	{
		l1 = hd l :: l1;
		l = tl l;
	}
	return (reverse(l1), l);
}



reverse(l: list of ref Entry): list of ref Entry
{
	l1: list of ref Entry = nil;
	while(l != nil)
	{
		l1 = hd l :: l1;
		l = tl l;
	}
	return l1;
}

