

Gitindex : module
{
	PATH: con "/dis/git/gitindex.dis";
	CACHESIGNATURE: con 16r44495243;
	STAGEMASK: con 16r3000;
	EXTENDEDENTRY: con 16r4000; 
	STAGESHIFT: con 12;


	HEADERSZ: con 12;
#This is a entry size up to name field
	ENTRYSZ:  con 40; 

#This constant is used for determining whether hash 
#table needs resizing. If entriesnt * CLSBND >= hashcap,
#then hash table needs resizing
	CLSBND:   con 3;

	Header: adt
	{
		signature:  int;
		version:    int;
		entriescnt: int;

		pack:     fn(header: self ref Header): array of byte;
		unpack:   fn(buf: array of byte): ref Header;
		new:	  fn(): ref Header;
	};

	
	Entry: adt
	{
		qid:     Sys->Qid;
		sha1:    array of byte;
		flags:	 int;
		name:    string;

		pack:  fn(entry: self ref Entry): array of byte;
		unpack:    fn(buf: array of byte): ref Entry;
		compare: fn(e1: self ref Entry, e2: ref Entry): int;
		new:     fn(): ref Entry;
	};

	Index: adt
	{
		header:     ref Header;
		entries:    ref Tables->Strhash[ref Entry]; 	
		hashcap:    int;
		addfile:    fn(index: self ref Index, path: string): string;
		addentry:   fn(index: self ref Index, entry: ref Entry);
		getentries: fn(index: self ref Index, stage: int): list of ref Entry;
		removeentries: fn(index: self ref Index): ref Index;
		rmfile:     fn(index: self ref Index, path: string);
		new:        fn(arglist: list of string, debug: int): ref Index;
	};
	
	init: fn(mods: Mods);
	initindex: fn(): Index;
	printindex: fn(index: ref Index);
	readindex:  fn(index: ref Index): int;
	readindexfromsha1: fn(sha1: string): Index;
	writeindex: fn(index:ref Index): int;

};
