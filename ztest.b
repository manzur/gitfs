implement Ztest;

include "sys.m";
	sys: Sys;

include "draw.m";
include "daytime.m";
	daytime: Daytime;
	
include "filter.m";
	inflate: Filter;
	deflate: Filter;

Ztest: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	inflate = load Filter Filter->INFLATEPATH;
	deflate = load Filter Filter->DEFLATEPATH;
	daytime = load Daytime Daytime->PATH;
	inflate->init();
	deflate->init();
	sys->print("--%d--\n",daytime->now());
	sys->print("--%s--\n",daytime->time());
	path1 := "text";
	path2 := "objects/f9/338121f61abecfe310b5f68d1893389193479d";
#	deflatefile(path1);
	inflatefile(path2);
#	modetest("objects");
}


modetest(path: string)
{
	sys->print("in modetest\n");
	(ret, dirstat) := sys->stat(path);
	if(ret == -1)
	{
		sys->print("stat error: %r\n");
		return;
	}
	sys->print("%d\n", dirstat.mode >> 31);
	if(dirstat.mode >> 31 == -1)
		sys->print("dir\n");
	sys->print("out modetest\n");
}
#48f44c752605481273d1cb92185ff3e09ddd00b8

deflatefile(path: string)
{
	fd := sys->open(path, Sys->OREAD);
	if(fd == nil) return;
	rqchan := deflate->start("z");
	old := array[0] of byte;
	while(1)
	{
		pick rq := <-rqchan
		{
			Start => sys->print("Started: %d\n", rq.pid);
			Finished => if(len rq.buf > 0) sys->print("Data remained\n");
				    return save2file(path, old);

			Result => 
				new := array[len old + len rq.buf] of byte;
				new[:] = old;
				new[len old:] = rq.buf;
				old = new;
				rq.reply <-= 0;
			Fill => 
				sys->print("len: %d\n", len rq.buf);
				buf := array[len rq.buf] of byte;
				cnt := sys->read(fd, buf, len buf); 
				sys->write(sys->fildes(1), buf, cnt);
				rq.buf[:] = buf;
				rq.reply <-= cnt;
			Error =>
				sys->print("error ocurred: %r\n");
				return;
		}
	}
}

save2file(path: string, buf: array of byte)
{
	if((fd := sys->create("text.zip",Sys->OWRITE, 0644)) == nil)
	{
		sys->print("file can't be created\n");
		return;
	}
	sys->write(fd, buf, len buf);
}

inflatefile(path: string)
{
	fd := sys->open(path, Sys->OREAD);
	sys->print("in inflate: %r\n");
	if(fd == nil) return;
	sys->print("after if\n");
	rqchan := inflate->start("z");
	old := array[0] of byte;
	while(1)
	{
		pick rq := <-rqchan
		{
			Start => sys->print("Started: %d\n", rq.pid);
			Finished => if(len rq.buf > 0) sys->print("Data remained\n");
				    sys->write(sys->fildes(1), old, len old);
				    return;

			Result => 
				new := array[len old + len rq.buf] of byte;
				new[:] = old;
				new[len old:] = rq.buf;
				old = new;
				rq.reply <-= 0;
			Fill => 
				buf := array[len rq.buf] of byte;
				cnt := sys->read(fd, buf, len buf); 
				rq.buf[:] = buf;
				rq.reply <-= cnt;
			Error =>
				if(fd == nil)
					sys->print("---+++\n");
				sys->print("%s\n",rq.e);
				return;
		}
	}

}

