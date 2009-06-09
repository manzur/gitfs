implement Writetree;

include "sys.m";
	sys: Sys;

include "draw.m";

include "tables.m";
	tables: Tables;
Strhash: import tables;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "utils.m";
	utils: Utils;
int2string, bufsha1, save2file, string2path, sha2string, SHALEN: import utils;

include "gitindex.m";
	gitindex: Gitindex;
Index, Entry: import gitindex;


include "filter.m";
	deflate: Filter;

Writetree: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};


init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	deflate = load Filter Filter->DEFLATEPATH;
	tables = load Tables Tables->PATH;
	utils = load Utils Utils->PATH;

	utils->init();
	deflate->init();
	gitindex = load Gitindex Gitindex->PATH;
	sys->print("new tree: %s\n", writetreefile());
}


writetreefile(): string
{
	
	index := Index.new();
	index.readindex("index");


	filelist := array[0] of byte;
	for(l := mergesort(index.entries.all()); l != nil; l = tl l)
	{
		#F***ing zero; There's no way to write 0 byte except converting list to the array of byte
		#Don't blame me for this stupid code

		entry := hd l;
		sys->print("Writing: %s\n", entry.name);
		entry.mode = fillmode(entry.mode);
		sys->print("mode: %o", entry.mode);
		temp := array of byte sys->sprint("%o %s", entry.mode, entry.name);
		oldfilelist := filelist;
		filelist = array[len oldfilelist + len temp + 1 + SHALEN] of byte;
		filelist[:] = oldfilelist;
		offset := len oldfilelist;
		filelist[offset:] = temp;
		offset += len temp;
		filelist[offset:] = entry.sha1;
	}
	fsize := len array of byte filelist;

	header := sys->sprint("tree %d", fsize );
	headerlen := len array of byte header;

	#+1 is for 0 byte,which is used as a separator
	buf := array[len header + len filelist + 1] of byte;
	buf[:] = array of byte header;
	buf[headerlen] = byte 0;
	buf[headerlen + 1:] = filelist;


	ch := chan of (int, array of byte);
	spawn utils->writesha1file(ch);
	sha: array of byte;
	sz: int;
	ch <-= (len buf, buf);
	ch <-= (0, buf);
	(sz, sha) = <-ch;
	
	return sha2string(sha);
}

fillmode(mode: int): int
{
	mode &= 1023;
	mode |= 16384;
	return mode;
}

mergesort(l: list of ref Entry): list of ref Entry
{
	if(len l > 1)
	{
		sys->print("in mergesort: %d\n", len l);
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

