
Checkoutmod: module
{
	PATH: con "/dis/git/checkout.dis";

	init: fn(m: Mods);
	checkout: fn(index: ref Gitindex->Index, sha1: string): ref Gitindex->Index;
};

