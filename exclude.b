implement Exclude;

include "exclude.m";

include "sys.m";
	sys: Sys;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;

include "regex.m";
	regex: Regex;
Re: import regex;
	
regexp: Re;

stderr: ref Sys->FD;
excluderegexp: list of Re = nil;

init()
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	regex = load Regex Regex->PATH;
	stderr = sys->fildes(2);
	ibuf := bufio->open(EXCLUDEPATH, Bufio->OREAD);
	if(ibuf == nil)
	{
		sys->fprint(stderr, "excude file couldn't be found\n");
		return;
	}
	while((s := ibuf.gets('\n')) != "")
	{
		s = s[:len s - 1];
		(regexp, diag) := regex->compile(s,0);
		if(regexp == nil)
		{
			sys->fprint(stderr, "error in regexp(%s): %s\n", s, diag);
			continue;
		}
		excluderegexp = regexp :: excluderegexp;
	}
}

excluded(path: string): int
{
	for(l := excluderegexp; l != nil; l = tl l)
	{
		a := regex->execute(hd l, path);	
		if(a != nil && a[0].t0 >= 0)
			return 1;
	}
	return 0;
}






