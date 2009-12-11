
Treemod: module
{
	PATH: con "/dis/git/tree.dis";

	Tree: adt{
		sha1: string;
		#mode, path, sha1 for each entry
		children: list of (int, string, string);
	};

	init: fn(mods: Mods);
	readtree: fn(sha1: string): ref Tree;
	readtreebuf: fn(sha1: string, filebuf: array of byte): ref Tree;
	writetree: fn(index: ref Gitindex->Index): string;
	writetreefile: fn(entrylist: list of ref Gitindex->Entry, basename: string): (array of byte, list of ref Gitindex->Entry);
};

