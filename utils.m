
Utils: module
{
	PATH: con "utils.dis";
	QIDSZ:    con 16;
	BIGSZ:    con 8;
	INTSZ:    con 4;
	SHALEN:   con 20;
	INDEXPATH: con "index";
	OBJECTSTOREPATH: con "objects";
	CONFIGFILEPATH: con "config";

	Config: adt
	{
		attr, val: string;
	};

	init:          fn();
	
	writesha1file: fn(ch: chan of (int, array of byte));
	readsha1file:  fn(path: string): (string, int, array of byte);

	filesha1:      fn (path: string): array of byte;
	bufsha1:       fn(buf: array of byte): array of byte;
	
	int2string:    fn(num: int): string;

	save2file:     fn(path: string, buf: array of byte): int;
	string2path:   fn(filename: string): string;
	sha2string:    fn(sha: array of byte): string;
	exists:	       fn(shaname: string): int;

	bytes2int:     fn(buf: array of byte, offset: int): int;
	bytes2big:     fn(buf: array of byte, offset: int): big;
	big2bytes:     fn(n: big): array of byte;
	int2bytes:     fn(number: int): array of byte;
	allocnr:       fn(num: int): int;

	copyarray:     fn(dst: array of byte, doffset: int, src: array of byte, soffset, count : int);

	equalqids:     fn(q1,q2: Sys->Qid): int;
	extractfile:   fn(shafilename: string): string;

	getuserinfo:   fn():ref Strhash[ref Config];

	chomp:         fn(s: string): string;

	readline:      fn(ibuf: ref Iobuf): string;

};


