
Checkoutmod: module
{
	PATH: con "/dis/git/checkout.dis";

	checkout: fn(sha1: string): ref Gitindex->Index;
	init: fn(m: Mods);
};

