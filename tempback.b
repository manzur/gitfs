	Shaitem: adt{
		count: int;
		shaobject: ref Shaobject;
	};

	Shatable: adt{
		table: ref Strhash[ref Shaitem];

		add: fn(sha1: string, shaobject: ref Shaobject);
		all: fn(): list of ref Shaobject;
		del: fn(sha1: string);
		find: fn(sha1: string): ref Shaobject;
	};

Shatable.new(sha1: string): ref Shaobject
{
	item := table.find(sha1);
	if(item == nil){
		item = ref Shaitem(0, shaobject);
		table.add(sha1, item);
	}
	item.count++;

	return item.shaobject;
}

Shatable.del(sha1: string)
{
	item := table.find(sha1);
	if(item != nil){
		item.count--;
		if(item.count == 0)
			table.del(sha1);
	}
}

Shatable.find(sha1: string): ref Shaobject
{
	item := table.find(sha1);
	if(item != nil)
		return item.shaobject;

	return nil;
}

Shatable.all(): list of ref Shaobject
{
	items := table.all();

	l: list of ref Shaobject;
	while(items != nil){
		l = (hd items).shaobject :: l;
		items = tl items;
	}

	return l;
}
