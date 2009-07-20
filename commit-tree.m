
Committree: module
{
	PATH: con "/dis/git/commit-tree.dis";

	init: fn(args: list of string, debug: int);
	commit: fn(treesha: string, parents: list of string, comments: string): string;
};
