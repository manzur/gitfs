Writetree: module
{
	PATH: con "/dis/git/write-tree.dis";

	init: fn(mods: Mods);
	writetree: fn(index: ref Gitindex->Index): string;
};

