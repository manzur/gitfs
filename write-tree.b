implement Writetree;

include "sys.m";
	sys: Sys;

include "draw.m";

include "tables.m";
	tables: Tables;

Strhash: import tables;

include "utils.m";
	utils: Utils;


include "gitindex.m";
	gitindex: Gitindex;

Index: import gitindex;

include "filter.m";
	deflate: Filter;

int2string, bufsha1, save2file, string2path, sha2string: import utils;

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
	
	index := gitindex->Index.new();
	index.readindex("index");


	filelist: string = "";
	for(l := index.entries.all(); l != nil; l = tl l)
	{
		entry := hd l;
		filelist += sys->sprint("%o %s", entry.mode, entry.name);
		filelist += string array[1] of {byte 0};
		filelist += sha2string(entry.sha1);
	}
	fsize := len array of byte filelist;

	header := sys->sprint("tree %d", fsize);

	buf := array of byte (header + filelist);
	offset := 0;

	rqchan := deflate->start("z");
	old := array[0] of byte;
mainloop:
	while(1)
	{
		pick rq := <-rqchan
		{
			Finished => if(len rq.buf > 0) 
					sys->print("Data remained\n");
				    break mainloop;

			Result => 
				new := array[len old + len rq.buf] of byte;
				new[:] = old;
				new[len old:] = rq.buf;
				old = new;
				rq.reply <-= 0;

			Fill => 
				cnt := len rq.buf;
				if(cnt > len buf - offset)
					cnt = len buf - offset;
				rq.buf[:] = buf[offset:offset + cnt];
				offset += cnt;
				rq.reply <-= cnt;

			Error =>
				sys->print("error ocurred: %s\n", rq.e);
				return "";
		}
	}
		
	sha := bufsha1(old);		    
	treename := string2path(sha2string(sha));
	save2file(treename, old);

	return treename;
}



