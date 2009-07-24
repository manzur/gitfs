
Commitmod: module{
	PATH: con "/dis/git/commit.dis";

	Commit: adt{
		sha1: string;
		treesha1: string;
		parents: list of string; 
		author: string;
		committer: string;
		encoding: string;
		date: ref Daytime->Tm;
		comment: string;
	};

	init: fn(mods: Mods);
	readcommit: fn(sha1: string): ref Commit;
	readcommitbuf: fn(sha1: string, buf: array of byte): ref Commit;
};

