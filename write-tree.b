implement Writetree;

include "gitfs.m";
include "mods.m";
include "modules.m";

sprint: import sys;
Index, Entry: import gitindex;
bufsha1, mergesort, sha2string, SHALEN: import utils;

mods: Mods;
init(m: Mods)
{
	mods = m;
	deflatefilter->init();
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
