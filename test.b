implement Mymodule;


include "sys.m";
	sys : Sys;

include "tables.m";
	tables : Tables;

Strhash, Table : import tables;


include "draw.m";
include "bufio.m";
	bufio: Bufio;

Iobuf: import bufio;	

include "string.m";

include "utils.m";
	utils: Utils;

include "lists.m";
	lists: Lists;

include "readdir.m";
	readdir: Readdir;
	
include "filepat.m";
	filepath: Filepat;

include "exclude.m";
	exclude: Exclude;


print : import sys;

global: int;

Mymodule : module
{
	init : fn(nil : ref Draw->Context, args : list of string);
};

Diff: module
{
	init : fn(nil : ref Draw->Context, args : list of string);
};

Someadt : adt
{
	name : string;
	age : int;
	print : fn(someadt : self Someadt);
	
};

Cmp: adt[T]
{
	cmp: fn(t1, t2: T): int;
};

Cmp[T].cmp(t1, t2: T): int
{
	return 0;
}


Someadt.print(someadt : self Someadt)
{
	print("Name : %s\n", someadt.name);
	print("Age  : %d\n", someadt.age);
}

strchr(s: string, ch: int): int
{
	for(i:=0; i < len s; i++)
	{
		if(s[i] == ch)
			return i;
	}

	return -1;

}

include "test1.m";
	test1: Test1;

include "arg.m";
	arg: Arg;

DD: adt{
	i: big;
	d: ref Sys->Dir;
};

DD1: adt{
	i: big;
	d: ref Sys->Dir;
	pl:  cyclic array of ref DD;
};

init(nil : ref Draw->Context, args : list of string)
{
	sys = load Sys Sys->PATH;
	tables = load Tables Tables->PATH;
	readdir = load Readdir Readdir->PATH;
	filepat := load Filepat Filepat->PATH;
	exclude  = load Exclude Exclude->PATH;

	sys->print("from makefileisaidisaid\n");
	table := Table[ref DD].new(13, nil);
	sys->print("%bd;%bd", big string big 15, big 15);
}

testlist(l: list of ref Someadt)
{
	r := l;
	while(r != nil){
		if((hd r).name == "b")
			(hd r).age = 14;
		r = tl r;
	}
}

output()
{
	fd := sys->open("text1", Sys->OWRITE);
	buf := array[10] of byte;
	buf[:] = array of byte "text1";
	buf[5] = byte 0;
	buf[6:] = array of byte "next";
	sys->write(fd, buf, len buf);
}

printlist(l: list of int) 
{
	while(l != nil)
	{
		sys->print("%d ", hd l);
		l = tl l;
	}
	sys->print("\n");
}


Val: adt
{
	attr, val: string;
};


commucate(ch: chan of array of byte)
{
	count := 0;
	while(1)
	{
		b := <- ch;
		if(b[0] == byte 0 || count > 3)
		{
			sys->print("\ngot end\n");
			ch <-= array[1] of {byte -1};
			break;
		}
		count++;
		sys->print("\n<===%s===>\n", string b);
		sys->write(sys->fildes(1), b, len b);
		sys->print("from+++ comm\n");
		ch <-= array[1] of {byte 0};
	}
}

getuserinfo()
{
	str := load String String->PATH;
	bufio = load Bufio Bufio->PATH;
	buf := bufio->open("config", Bufio->OREAD);

	tab: ref Strhash[ref Val] = Strhash[ref Val].new(4, nil);

	while((s := buf.gets('\n')) != "")
	{
		if(s == "\n")
			return;
		s = s[:len s - 1];
		(s1, s2) := str->splitl(s,"=");
		s2 = s2[1:];
		val: ref Val = ref Val(s1, s2);

		tab.add(s1, val);

	}
	for(l := tab.all(); l != nil; l = tl l)
	{
		sys->print("%s=%s\n", (hd l).attr, (hd l).val);
	}
}


mergesort(l: list of int): list of int
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

merge(l1, l2: list of int): list of int
{
	if(l1 == nil)
		return l2;
	if(l2 == nil)
		return l1;
	
	l: list of int = nil;
	while(l1 != nil && l2 != nil)
	{
		if(hd l1 < hd l2)
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

partitionbypos(l: list of int, pos: int): (list of int, list of int)
{
	if(len l < pos)
		return (l, nil);
	l1 : list of int;
	for(i := 0; i < pos; i++)
	{
		l1 = hd l :: l1;
		l = tl l;
	}
	return (reverse(l1), l);
}



reverse(l: list of int): list of int
{
	l1: list of int = nil;
	while(l != nil)
	{
		l1 = hd l :: l1;
		l = tl l;
	}
	return l1;
}


usage()
{
	sys->fprint(sys->fildes(2),"sadasd");
	exit;
}
