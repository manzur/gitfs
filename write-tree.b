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
int2string, bufsha1, save2file, string2path, sha2string, SHALEN, INDEXPATH: import utils;

include "gitindex.m";
	gitindex: Gitindex;
Index, Entry: import gitindex;


include "filter.m";
	deflate: Filter;

include "string.m";
	stringmodule: String;

Writetree: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

index: ref Index;

outfd: ref Sys->FD;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	deflate = load Filter Filter->DEFLATEPATH;
	tables = load Tables Tables->PATH;
	utils = load Utils Utils->PATH;
	stringmodule = load String String->PATH;

	utils->init();
	deflate->init();
	gitindex = load Gitindex Gitindex->PATH;
	outfd = sys->create("output", Sys->OWRITE, 8r644);
	sys->print("new tree: %s\n", writetree());
}

writetree(): string
{
	index = Index.new();
	index.readindex(INDEXPATH);

	l := mergesort(index.entries.all());
	sys->print("files:\n");
	l1 := l;
	while(l1 != nil)
	{
		sys->print("file: %s\n", (hd l1).name);
		l1 = tl l1;
	}
	return sha2string(writetreefile(l, "").t0);
}

writetreefile(entrylist: list of ref Entry, basename: string): (array of byte, list of ref Entry)
{
	offset := 0;
	filelist := array[Sys->ATOMICIO] of byte;
	while(entrylist != nil)
	{
		sys->print("in while\n");
		entry := hd entrylist;
		if(len basename >= len entry.name || !stringmodule->prefix(basename, entry.name))
			break;

		mode := entry.mode;
		sha1 := entry.sha1;
		name := entry.name;
		rest: string;
		sys->print("name is: %s; mode is %d; sha1 is %s\n", name,mode,sha2string(sha1));
		(name, rest) = stringmodule->splitl(name[len basename:], "/");
		mode |= 32768;
		if(rest != "")
		{
			sys->print("in if\n");
			(sha1, entrylist) = writetreefile(entrylist, basename + name + "/");
			mode &= 1023;
			mode = mode | 16384;

		}
		record := array of byte sys->sprint("%o %s", mode, name);
		sys->write(sys->fildes(1), record, len record);
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
		sys->print("mode is %o\n", mode);
		if(entrylist != nil)
			entrylist = tl entrylist;
	}

	sys->print("size is: %d\n", offset);
	header := sys->sprint("tree %d", offset);
	headerlen := len array of byte header;

	#+1 is for 0 byte,which is used as a separator
	buf := array[headerlen + offset + 1] of byte;
	buf[:] = array of byte header;
	buf[headerlen] = byte 0;
	buf[headerlen + 1:] = filelist[:offset];

	ch := chan of (int, array of byte);
	spawn utils->writesha1file(ch);
	sha: array of byte;
	sz: int;
	ch <-= (len buf, buf);
	ch <-= (0, buf);
	(sz, sha) = <-ch;
	
	return (sha, entrylist);
}

#used for compatibility with unix mode
fillmode(mode: int): int
{
	if(mode & Sys->DMDIR)
	{
		mode &= 1023;
		mode |= 16384;
		return mode;
	}
	return mode & 1023;
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

