
Gitfs: module
{
	Querydata: adt{
		data: list of string;
	};

	Readquery: adt{
		fid: int;
		qdata: ref Querydata;

		contains: fn(readmdata: self ref Readquery, s: string): int;
		eq: fn(a, b: ref Readquery): int;
	};

	Head: adt{
		name, sha1: string;
	};

	#permanent part
	Shaobject: adt{
		dirstat: ref Sys->Dir;
		children: list of big;

	#This field(sha1) can be sha1 and also can be path to the file if it's in the
	#checked out working directory
		sha1: string;
		otype: string;

	#This field's used from some kind of optimization to
	#escape rereading
		data: array of byte;
	};

	#modifiable part
	Direntry: adt{	
		path, parent: big;
		name: string;
		object: ref Shaobject;
	
		getdirstat: fn(direntry: self ref Direntry): ref Sys->Dir;
		getfullpath: fn(direntry: self ref Direntry): string;
	};

	init: fn(nil: ref Draw->Context, args: list of string);
};
 
