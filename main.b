implement Main;

include "sys.m";
	sys: Sys;

include "draw.m";

include "filter.m";
	deflate: Filter;

Main: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};


init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	deflate = load Filter Filter->DEFLATEPATH;
	if(deflate == nil){
		sys->print("deflate not loaded: %r\n");
		exit;
	}
	deflate->init();
	rqchan := deflate->start("z1");
	old := array[0] of byte;
	send := 0;
	buf := array[128] of byte; 
	infd := sys->open("zipme", Sys->OREAD);
	cnt1 := sys->read(infd, buf, len buf);
	buf = buf[:cnt1];
	sys->write(sys->fildes(1), buf, len buf);
mainloop:
	while(1)
	{
		pick rq := <-rqchan
		{
			Finished =>
				    break mainloop;

			Result => 
				new := array[len old + len rq.buf] of byte;
				new[:] = old;
				new[len old:] = rq.buf;
				old = new;
				rq.reply <-= 0;

			Fill => 
				if(!send){
					rq.buf[:] = buf;
					rq.reply <-= len buf;
					send = 1;
				}else
				{
					rq.buf = nil;
					rq.reply <-= 0;
				}
			Error =>
				sys->print("error ocurred: %s\n", rq.e);
				return;
		}
	}
		
	fd := sys->create("output2", Sys->OWRITE, 8r644);
	cnt := sys->write(fd, old, len old);
	if(cnt != len old){
		sys->print("something wrong with writing to the file\n");
	}
}
