
Commitmod: module{
	Commit: adt{
		sha1: string;
		author: string;
		committer: string;
		date: ref Tm;
		treesha: string;
		comment: string;
		parents: list of string; 
	};

};

