

Gitindex : module
{
	PATH: con "gitindex.dis";
	CACHESIGNATURE: con 16r44495243;

	HEADERSZ: con 32;
#This is a entry size up to name field
	ENTRYSZ:  con 64; 

#This constant is used for determining whether hash 
#table needs resizing. If entriesnt * CLSBND >= hashcap,
#then hash table needs resizing
	CLSBND:   con 3;

	Header: adt
	{
		signature:  int;
		version:    int;
		entriescnt: int;
		sha1:       array of byte;
		pack:       fn(buf: array of byte): ref Header;
		unpack:     fn(header: self ref Header): array of byte;
		new:	    fn(): ref Header;
	};

	
	Entry : adt
	{
		qid:     Sys->Qid;
		dtype:   int;
		dev:     int;
		mtime:   int;
		mode:    int;
		length:  big;
		sha1:    array of byte;
		namelen: int;
		name:    string;
		pack:    fn(buf: array of byte): ref Entry;
		unpack:  fn(entry: self ref Entry): array of byte;
		compare: fn(e1: self ref Entry, e2: ref Entry): int;
	};

	Index : adt
	{
		header:     ref Header;
		entries:    ref Strhash[ref Entry]; 	
		hashcap:    int;
		addfile:    fn(index: self ref Index, path: string): int;
		rmfile:     fn(index: self ref Index, path: string);
		readindex:  fn(index: self ref Index, path: string): int;
		writeindex: fn(index: self ref Index, path: string): int;
		new:        fn(): ref Index;
	};
	
		
};
