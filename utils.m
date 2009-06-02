
Utils: module
{
	PATH: con "utils.dis";
	QIDSZ:    con 16;
	BIGSZ:    con 8;
	INTSZ:    con 4;
	SHALEN:   con 20;

	init:          fn();
	
	writeblobfile: fn(path: string): int;
	readsha1file:  fn(path: string): array of byte;

	filesha1:      fn(path: string): array of byte;
	bufsha1:       fn(buf: array of byte): array of byte;
	
	int2string:    fn(num: int): string;

	save2file:     fn(path: string, buf: array of byte): int;
	string2path:   fn(filename: string): string;
	sha2string:    fn(sha: array of byte): string;
};

