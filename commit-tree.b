implement Committree;

include "sys.m";
	sys: Sys;

include "draw.m";

include "arg.m";
	arg: Arg;

include "utils.m";
	utils: Utils;

include "filter.m";
	deflate: Filter;
		
include "bufio.m";
	bufio: Bufio;

Iobuf: import bufio;

Committree: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};



init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	utils = load Utils Utils->PATH;
	deflate = load Filter Filter->DEFLATEPATH;
	bufio = load Bufio Bufio->PATH;

	arg->init(args);
	utils->init();
	deflate->init();

	parents: list of string = nil;

	if(len args < 2)
	{
		usage();
		return;
	}
	
	sys->print("before while\n");
	sha := arg->arg();
	sys->print("got sha: %s\n", sha);

	while((c := arg->opt()) != 0)
	{
		case c
		{

			'p' => parents = arg->arg() :: parents;
			 *  => usage(); return; 
		}
	}

	commit(sha, parents);
	sys->print("after while\n");

}

#FIXME: Commit, Writetree and Writeblob should be generalized and merged
commit(treesha: string, parents: list of string): string
{
	if(utils->exists(treesha) == 0)
	{
		sys->fprint(sys->fildes(2), "no such tree file\n");
		return "";
	}
	for( l = parents; l != nil; l = tl l)
	{
		if(exists(hd l) == 0){
			sys->fprint(sys->fildes(2), "no such sha file: %s\n", hd l);
			return "";
		}

	}
	commitmsg := "";
	commitmsg += "tree " + treesha + "\n";
	while(parents != nil)
	{
		commitmsg += "parent " + (hd parents) + "\n";
		parents = tl parents;
	}
	#FIXME: user Info should be read from config file or extracted from system files
	#getuserinfo();
	gecos  := "Manzur";
	email  := "gg@gg.com";
	date   := "04.06.09";
	commitmsg += "author " + gecos + " " + email + " " + date + "\n";
	#real data
	commitmsg += "committer " + gecos + " " + email + " " + date + "\n\n";
	
	commitmsg += getcomment();

	size := len commitmsg;
	buf := array of byte ("commit " + utils->int2string(size) + string (byte 0) + commitmsg);

	sys->print("Commitmsg: %s\n", commitmsg);
	rqchan := deflate->start("z");
	old := array[0] of byte;
	offset := 0;
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
		
	sha := utils->bufsha1(old);		    
	commitname := utils->string2path(utils->sha2string(sha));
	utils->save2file(commitname, old);

	sys->print("Commited to: %s\n", commitname);

	return commitname;

}


getcomment(): string
{
	ibuf := bufio->fopen(sys->fildes(0), bufio->OREAD);	
	return ibuf.gets('\0');
}

usage()
{
	sys->fprint(sys->fildes(1), "commit-tree sha1 [-p sha1]");
	return;
}
