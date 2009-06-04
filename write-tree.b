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


include "filter.m";
	deflate: Filter;

int2string, bufsha1, save2file, string2path, sha2string, SHALEN: import utils;
Index: import gitindex;

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
	for(l := index.entries.all(); l != nil; l = tl l)
	{
		#F***ing zero; There's no way to write 0 byte except converting list to the array of byte
		#Don't blame me for this stupid code

		entry := hd l;
		temp := array of byte sys->sprint("%o %s", entry.mode, entry.name);
		oldfilelist := filelist;
		filelist = array[len oldfilelist + len temp + 1 + SHALEN] of byte;
		filelist[:] = oldfilelist;
		offset := len oldpfilelist;
		sys->print("off2: %d\n", offset);
		filelist[offset:] = temp;
		offset += len temp;
		sys->print("off2: %d\n", offset);
		#filelist[offset:] = entry.sha1;
		sys->write(sys->fildes(1), temp, len temp);
		sys->print("sep\n");
		sys->write(sys->fildes(1), filelist, len filelist);
	}
	fsize := len array of byte filelist;

	sys->print("[[[[%d]]]]\n", fsize);

	header := sys->sprint("tree %d", fsize );
	headerlen := len array of byte header;

	#+1 is for 0 byte,which is used as a separator
	buf := array[len header + len filelist + 1] of byte;
	buf[:] = array of byte header;
	buf[headerlen] = byte 0;
	buf[headerlen + 1:] = filelist;

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



