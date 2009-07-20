
Treemod: module
{
	PATH: con "/dis/git/tree.dis";

	Tree: adt{
		sha1: string;
		#mode, path, sha1 for each entry
		children: list of (int, string, string);
	};

	init: fn(arglist: list of string, debug: int);
	readtree: fn(sha1: string): ref Tree;
	readtreebuf: fn(sha1: string, filebuf: array of byte): ref Tree;
};

