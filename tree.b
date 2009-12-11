implement Treemod;

include "gitfs.m";
include "mods.m";
include "modules.m";

sprint: import sys;
Index, Entry: import gitindex;
splitl, toint: import stringmod;	
bufsha1, mergesort, error, readsha1file, sha2string, SHALEN: import utils;

mods: Mods;

init(m: Mods)
{
	mods = m;
	deflatefilter->init();
}

readtree(sha1: string): ref Tree
{
	sys->print("reading tree %s\n", sha1);
	(filetype, filesize, filebuf) := readsha1file(sha1);
	if(filetype != "tree"){
		error(sprint("%s is not tree\n", sha1));
		return nil;
	}

	return readtreebuf(sha1, filebuf);
}

readtreebuf(sha1: string, filebuf: array of byte): ref Tree
{	
	children: list of (int, string, string);
	ibuf := bufio->aopen(filebuf);
	while((s := ibuf.gets('\0')) != ""){
		(mode, path) := splitl(s, " ");
		sha1 := array[SHALEN] of byte;
		cnt := ibuf.read(sha1, len sha1);
		path = path[1:len path-1];
		shastr := sha2string(sha1);
		children = (toint(mode, 8).t0, path, shastr) :: children;
	}
	
	return ref Tree(sha1, reverse(children));
}

writetree(index: ref Index): string
{
	l := mergesort(index.entries.all());
	
#FIXME: del the printing code
	l1 := l;
	while(l1 != nil){
		sys->print("==>%s\n", (hd l1).name);
		l1 = tl l1;
	}
	


	return sha2string(writetreefile(l, "").t0);
}

writetreefile(entrylist: list of ref Entry, basename: string): (array of byte, list of ref Entry)
{
	sys->print("entrylist len is %d\n", len entrylist);
	offset := 0;
	filelist := array[Sys->ATOMICIO] of byte;
	while(entrylist != nil)
	{
		entry := hd entrylist;
		if(!stringmod->prefix(basename, entry.name))
			break;

		sys->print("IN WRITETREEFILE, basename: %s; filename: %s\n", basename, entry.name);
		sha1 := entry.sha1;
		name := entry.name;

		sys->print("ENNNNN: %s\n", entry.name);
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
		if(rest == nil)
			entrylist = tl entrylist;
	}

	header := sys->aprint("tree %bd", big offset);
	
#	#+1 is for 0 byte, which is used as a separator
	buf := array[len header + offset + 1] of byte;
	buf[:] = header[:];
	buf[len header] = byte 0;
	buf[len header + 1:] = filelist[:offset];

	ch := chan of (int, array of byte);
	spawn utils->writesha1file(ch);
	sha: array of byte; sz: int;
	ch <-= (len buf, buf);
	ch <-= (0, nil);
	(sz, sha) = <-ch;
	sys->print("tree is written to %s\n", sha2string(sha));

	return (sha, entrylist);
}

#FIXME: should use lists->reverse which need ref T, and doesn't work with tuples
reverse(l: list of (int, string, string)): list of (int, string, string)
{
	ret: list of (int, string, string);
	while(l != nil){
		ret = hd l :: ret;
		l = tl l;
	}

	return ret;
}
