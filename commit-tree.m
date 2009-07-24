
Committree: module
{
	PATH: con "/dis/git/commit-tree.dis";

	init: fn(mods: Mods);
	commit: fn(treesha: string, parents: list of string, comments: string): string;
};
