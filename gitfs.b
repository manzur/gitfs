implement Gitfs;

include "mods.m";
mods: Mods;
include "modules.m";

sprint: import sys;
Tmsg, Rmsg: import styx;
Fid, Navop, Navigator, Styxserver: import styxservers;
readcommitbuf, Commit: import commitmod;
printindex, readindex, readindexfromsha1, writeindex, Entry, Header, Index: import gitindex;
readtreebuf, writetree, Tree: import treemod;
basename, cleandir, makeabsentdirs, makepathabsolute, string2path, INDEXPATH, HEADSPATH: import pathmod;	
bufsha1, debugmsg, error, mktempfile, objectstat, sha2string, splitl, string2sha, strip, SHALEN: import utils;

include "gitfs.m";

QRoot, QStaticMax: con big iota;
TABLEINITSIZE: con 17;


debug: int;
heads: list of ref Head;
tags: list of ref Head;
indexkeyword := "index";
nav: ref Navigator;
readqueries: ref Table[list of Readquery];
srv: ref Styxserver;
rootfid: int;
table: ref Strhash[ref Direntry];
indices: ref Strhash[ref Index];
workingdir: ref Direntry;
QMax := QStaticMax;

init(nil: ref Draw->Context, args: list of string)
{
	mods = load Mods Mods->PATH;
	if(len args < 2)
		usage();

	arg := hd (tl args);
	if(len args == 3 && arg == "-d"){
		debug = 1;
		arg = hd (tl (tl args));
	}

	mods->init(arg, debug);
	initmodules();
	
	if(!repo->readrepo()){
		error("repository is wrong\n");
		exit;
	}
	#index = Index.new(arglist, debug);
	#readindex(index);

	sys->pctl(Sys->NEWPGRP, nil);
	inittable();

	configmod->readconfig("");
	if(configmod->getstring("gitfs.keyword") != nil){
		indexkeyword = configmod->getstring("gitfs.keyword");
	}

	styx->init();
	styxservers->init(styx);
#	styxservers->traceset(1);
	navch := chan of ref Navop;
	nav = Navigator.new(navch);
	spawn navigate(navch);
	tmsgchan: chan of ref Tmsg;
	(tmsgchan, srv) = Styxserver.new(sys->fildes(0), nav, big QRoot);
	spawn process(srv, tmsgchan);
}

addentry(ppath: big, name, sha1: string, dirstat: ref Sys->Dir, otype: string): big 
{
	path := QMax++;
	return addentrywithqid(path, ppath, name, sha1, dirstat, otype);
}

addentrywithqid(path, ppath: big, name, sha1: string, dirstat: ref Sys->Dir, otype: string): big 
{
	shaobject := ref Shaobject(dirstat, nil, sha1, otype, nil);
	direntry := ref Direntry(path, ppath, name, shaobject);

	table.add(string direntry.path, direntry);
	if(sha1 != nil)
		shatable.add(shaobject.sha1, shaobject);
	
	parent := table.find(string ppath);
	parent.object.children = path :: parent.object.children;

	return direntry.path;
}

adddirtoindex(indexpath, srcpath: big)
{
	direntry := table.find(string srcpath);
	l := direntry.object.children;
	while(l != nil){
		addfiletoindex(indexpath, hd l);
		l = tl l;
	}
}

addfiletoindex(indexpath, srcpath: big)
{
	index := indices.find(string indexpath);
	#add file to the index structure
	direntry1 := table.find(string srcpath);
	sys->print("adding file %s to index\n", direntry1.getfullpath());
	sha1 := index.addfile(direntry1.getfullpath());

	#Add entry in the file system hierarchy
	parent := table.find(string indexpath);
	(nil, direntry1.name) = stringmod->splitstrr(direntry1.getfullpath(),"/tree/");
	q := q1 := QMax++;
	(dir, rest) := basename(direntry1.name);
	ch: ref Direntry;
	sys->print("dirname==>%s\n", dir);
	while(dir != nil && (ch = child(parent, dir)) != nil){
		sys->print("==>WTFSSFSF\n");
		parent = ch;
		direntry1.name = rest;
		(dir, rest) = basename(direntry1.name);
	}
	sys->print("FUCK CH IS NIL:%d\n", ch == nil);
	if((ch = child(parent, direntry1.name)) != nil){
		sys->print("removing child from addfiletoindex\n");
		removechild(parent, ch.path);
		sys->print("after removechil\n");
		removeentry(ch.path);
		sys->print("after removeentry\n");
	}

	sys->print("ADDFILETOINDEX, size is %bd\n", direntry1.object.dirstat.length);

	(q, parent, direntry1.name) = makeabsententries(q, parent, direntry1.name, *direntry1.object.dirstat);
	#If no parents were absent we should decrement QMax to avoid junk qid.path
	if(q == q1) QMax--;
	path := addentry(parent.path, direntry1.name, sha1, direntry1.object.dirstat, "index");
}

addhead(name, sha1: string)
{
	head := ref Head(name, sha1);
	heads = head :: heads;
}

addheadfile(name, sha1: string)
{
	fd := sys->create(repopath + ".git/refs/heads/" + name, Sys->OWRITE, 8r644);
	buf := array of byte (sha1 + "\n");
	sys->write(fd, buf, len buf);
	addhead(name, sha1);
}

checkout(indexpath: big, parent: ref Direntry)
{
	cleandir(repopath[:len repopath-1]);
	index := indices.find(string indexpath);
	index = checkoutmod->checkout(index, parent.object.sha1);
	#FIXME: why removeentry here?
	#removeentry(QIndex);
	#initindex();
	treepath := big 0;
	l := parent.object.children;
	while(l != nil){
		item := table.find(string hd l);
		if(item.name == "tree"){
			treepath = hd l;
			break;
		}
		l = tl l;
	}
	mapworkingtree(treepath);
	workingdir = parent;
}

chdir()
{
	#It's needed to reconstruct the file system hierarchy
	g := gwd->init();
	sys->chdir(g);
}

child(parent: ref Direntry, name: string): ref Direntry
{
	l := parent.object.children;
	while(l != nil){
		ret := table.find(string hd l);
		if(ret != nil && ret.name == name){
			return ret;
		}
		l = tl l;
	}
	
	return nil;
}

createlogstat(parent: ref Direntry, dirstat: ref Sys->Dir, msg: string)
{
	q := QMax++;
	dirstat.mode = 8r644;
	shaobject := ref Shaobject(dirstat, nil, parent.object.sha1, nil, sys->aprint("%s", msg));
	direntry := ref Direntry(q, parent.path, "commit_msg", shaobject);
	table.add(string direntry.path, direntry);
	parent.object.children = direntry.path :: parent.object.children;

	#Adding log entry
	q = QMax++;
	shaobject = ref Shaobject(dirstat, nil, parent.object.sha1, "log", nil);
	direntry = ref Direntry(q, parent.path, "log", shaobject);
	table.add(string direntry.path, direntry);
	parent.object.children = direntry.path :: parent.object.children;
}

Direntry.getdirstat(direntry: self ref Direntry): ref Sys->Dir
{
	dirstat := *direntry.object.dirstat;
	dirstat.qid.path = direntry.path;
	dirstat.name = direntry.name;

	return ref dirstat;
}

Direntry.getfullpath(direntry: self ref Direntry): string
{
	name := direntry.getdirstat().name; 
	direntry = table.find(string direntry.parent);
	while(direntry != nil && direntry.path != QRoot){
		name = sprint("%s/%s", direntry.getdirstat().name, name);	
		direntry = table.find(string direntry.parent);
	}

	return name;
}

fillindexdir(index: ref Index, parent: ref Direntry, stage: int)
{
	direntry: ref Direntry;	shaobject: ref Shaobject;
	dirstat := sys->stat(repopath + INDEXPATH).t1;
	oldparent := parent;
	entries := index.getentries(stage);
	while(entries != nil){
		entry := hd entries;
		sys->print("entry: %s\n", entry.name);
		sha1 := sha2string(entry.sha1);
		q := QMax++;
		parent = oldparent; name: string;

		(q, parent, name) = makeabsententries(q, parent, entry.name, dirstat);
		dirstat = objectstat(sha1).t1;
		dirstat.mode = 8r644;
		shaobject = ref Shaobject(ref dirstat, nil, sha1, "index", nil);
		direntry = ref Direntry(q, parent.path, name, shaobject);
		sys->print("in fillindexdir: parent.path = %bd; name = %s; direntry.path=%bd\n", parent.path, name, direntry.path);
		parent.object.children = direntry.path :: parent.object.children;

		table.add(string direntry.path, direntry);
		shatable.add(sha1, shaobject);
		entries = tl entries;
	}
}

fillstage(shaobject: ref Shaobject, name: string, qid, parent: big, stage: int)
{
	direntry := ref Direntry(qid, parent, name, shaobject);
	table.add(string direntry.path, direntry);
	index := indices.find(string parent);
	fillindexdir(index, direntry, stage);
}

findchildren(ppath: big): list of ref Direntry 
{
	direntry := table.find(string ppath);
	if(direntry == nil)	
		return nil;

	sys->print("in findchildren: %s\n", direntry.name);
	if(direntry.object.children == nil && direntry.object.otype != "index"){
		#If the entry is checkouted
		if(direntry.object.otype == "work"){
			(dirs, nil) := readdir->init(direntry.object.sha1, Readdir->NAME);
			for(i := 0; i < len dirs; i++){
				path := QMax++;
				fullpath := direntry.object.sha1 + "/" + dirs[i].name;
				dirs[i].qid.path = path;
				s := ref Shaobject(dirs[i], nil, fullpath, "work", nil); 
				d := ref Direntry(path, direntry.path, dirs[i].name, s);
				table.add(string path, d);
				direntry.object.children = path :: direntry.object.children;
			}
		}
		else{
			readchildren(direntry.object.sha1, ppath);
		}
	}

	children: list of ref Direntry;
	l := direntry.object.children;
	while(l != nil){
		sys->print("%bd ==< child==>%bd\n", ppath, hd l);
		dentry := table.find(string hd l);
		if(dentry != nil){
			sys->print("FOUNDED DENTRY: %s\n", dentry.name);
			sys->print("dentry not nil: %bd\n", hd l);
			children = dentry :: children; 
		}
		l = tl l;
	}
	sys->print("in findchild: child = %d\n", len children);
	return children; 
}

getrecentcommit(path: big): ref Direntry
{
	parent: ref Direntry;
	do{
		parent = table.find(string path);
		path = parent.parent;
	}while(parent.object.otype != "commit");

	return parent;
}

getrecentindex(path: big): ref Direntry
{
	prevpath := path;
	while(path != QRoot){
		prevpath = path;
		parent := table.find(string path);
		path = parent.parent;
	}
	direntry := table.find(string prevpath);
	ch := child(direntry, "index");
	if(ch == nil){
		sys->print("there's no index directory in this branch");
		return nil;
	}

	return ch;
}

initindex(parent, qindex: big, sha1: string): big
{
	sys->print("initindex: parent = %bd\n", parent);
	#Adding index/ and subdirs
	(ret, dirstat) := sys->stat(repopath + INDEXPATH);
	if(ret == -1)
		error(sprint("Index file at %s is not found\n", repopath + INDEXPATH));

	qindex1 := QMax++;
	qindex2 := QMax++;
	qindex3 := QMax++;
	dirstat = *makedirstat(qindex, dirstat);
	shaobject := ref Shaobject(ref dirstat, qindex1 :: (qindex2 :: (qindex3 :: nil)), nil, "index", nil);
	direntry := ref Direntry(qindex, parent, "index", shaobject);
	table.add(string direntry.path, direntry);
	index := ref readindexfromsha1(sha1);
	printindex(index);
	indices.add(string qindex, index);
	fillindexdir(index, direntry, 0);

	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	fillstage(shaobject, "1", qindex1, qindex, 1);

	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	fillstage(shaobject, "2", qindex2, qindex, 2);
	
	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	fillstage(shaobject, "3", qindex3, qindex, 3);

	return qindex;
}

initmodules()
{
	catfilemod->init(mods);
	checkoutmod->init(mods);
	commitmod->init(mods);
	committree->init(mods);
	configmod->init(mods);
	gitindex->init(mods);
	log->init(mods);
	packmod->init(mods);
	pathmod->init(mods);
	repo->init(mods);
	treemod->init(mods);
	utils->init(mods);
}

inittable()
{
	indices = Strhash[ref Index].new(TABLEINITSIZE, nil);
	table = Strhash[ref Direntry].new(TABLEINITSIZE, nil);
	shatable = Strhash[ref Shaobject].new(TABLEINITSIZE, nil);
	readqueries = Table[list of Readquery].new(TABLEINITSIZE, nil);
	
	dirstat: Sys->Dir;
	direntry: ref Direntry;
	ret:int; l: list of big;
	shaobject: ref Shaobject;
	
	l1 := readheads(repopath + HEADSPATH, "");
	l2: list of ref Head = nil;
	#l2 := readpackedheads();
	heads = heads1 := mergelist(l1, l2);
	while(heads1 != nil){
		head := hd heads1;
		(ret, dirstat) = utils->objectstat(head.sha1);
		if(ret == -1){
			error(sprint("head %s couldn't be accessed\n", string2path(head.sha1)));
			heads1 = tl heads1;
			continue;
		}
		qbranch := QMax++;
		addbranch(qbranch, dirstat, head);
		l = qbranch :: l;
		heads1 = tl heads1;
	}
	l = inittags(dirstat) :: l;
	shaobject = ref Shaobject(makedirstat(QRoot, dirstat), l, nil, nil, nil);
	direntry = ref Direntry(QRoot, big -1, ".", shaobject);
	table.add(string direntry.path, direntry);
}

addbranch(qbranch: big, dirstat: Sys->Dir, head: ref Head)
{
	sys->print("IN ADD BRANCH\n");
	q := QMax++;
	#FIXME: use addentry here
	shaobject := ref Shaobject(makedirstat(q, dirstat), nil, head.sha1, "commit", nil);
	direntry := ref Direntry(q, qbranch, "head", shaobject);
	table.add(string direntry.path, direntry);
	shatable.add(shaobject.sha1, shaobject);

	qindex := QMax++;
	sys->print("qindex = %bd\n", qindex);
	#FIXME: use addentry
	shaobject = ref Shaobject(makedirstat(qbranch, dirstat), q :: (qindex :: nil), nil, "branch", nil);
	direntry = ref Direntry(qbranch, QRoot, head.name, shaobject);
	table.add(string direntry.path, direntry);
	shatable.add(shaobject.sha1, shaobject);
	initindex(qbranch, qindex, head.sha1);

}

isbranching(path: string): int
{
	cnt := 0;
	for(i := 0; i < len path && cnt <= 1; i++){
		if(path[i] == '/') cnt++;
	}

	return cnt >= 2;
}


inittags(dirstat: Sys->Dir): big
{
	children: list of big;
	readtags();
	l := tags;
	qtags := QMax++;
	while(l != nil){
		children = addtag(hd l, qtags, dirstat) :: children;	
		l = tl l;
	}
	shaobject := ref Shaobject(makedirstat(qtags, dirstat), children, nil, "tags", nil);
	direntry := ref Direntry(qtags, QRoot, "tags", shaobject);
	table.add(string direntry.path, direntry);

	return qtags;
}

addtag(tag: ref Head, parent: big, dirstat: Sys->Dir): big
{
	sys->print("IN ADD TAG\n");
	q := QMax++;
	#FIXME: use addentry here
	shaobject := shatable.find(tag.sha1);
	if(shaobject == nil){
		shaobject = ref Shaobject(makedirstat(q, dirstat), nil, tag.sha1, "commit", nil);
		shatable.add(shaobject.sha1, shaobject);
	}
	direntry := ref Direntry(q, parent, tag.name, shaobject);
	table.add(string direntry.path, direntry);

	return q;
}

readtags()
{
	path := repopath + ".git/refs/tags";
	(dirs, nil) := readdir->init(path, Readdir->NAME);
	for(i := 0; i < len dirs; i++){
		fpath := path + "/" + dirs[i].name;
		ibuf := bufio->open(fpath, Bufio->OREAD);
		if(ibuf == nil){
			error(sprint("ibuf is nil; path is %s\n", path + "/" + dirs[i].name));
			continue;
		}
		sha1 := strip(ibuf.gets('\n'));
		head := ref Head(dirs[i].name, sha1);
		tags = head :: tags;
	}
}

istreedir(direntry: ref Direntry): int
{
#FIXME: make more smarter check
	fullpath := direntry.getfullpath();
	(s, nil) := stringmod->splitl(fullpath, "/");
	l := heads; underbranch := 0;
	while(l != nil && !underbranch){
		head := hd l;
		if(stringmod->prefix(head.name, s)){
			underbranch = 1;
		}
		l = tl l;
	}

	(s, nil) = stringmod->splitstrr(fullpath, "/tree");

	return underbranch && s != nil;
}

makeabsententries(q: big, parent: ref Direntry, name: string, dirstat: Sys->Dir): (big, ref Direntry, string)
{
	(dirname, rest) := basename(name);
	while(dirname != nil){
		child := child(parent, dirname);
		if(child == nil){
			shaobject := ref Shaobject(makedirstat(q, dirstat), nil, nil, "index", nil); 
			child = ref Direntry(q, parent.path, dirname, shaobject);
			table.add(string child.path, child);
			parent.object.children = child.path :: parent.object.children;
		}
		parent = child;
		q = QMax++;
		(dirname, rest) = basename(rest);
	}

	sys->print("in makeabsententries: rest=%s\n", rest);
	return (q, parent, rest);
}

mapdir(path: string, item: ref Direntry)
{
	children := item.object.children;
	while(children != nil){
		childpath := hd children;
		child := table.find(string childpath);
		fullpath := sprint("%s/%s", item.object.sha1, child.name);
		dirstat := child.object.dirstat;
		children = tl children;
		if(dirstat.mode & Sys->DMDIR){
			if(child.object.children == nil)	
				readchildren(child.object.sha1, child.path);
			mapfile(fullpath, child);
			mapdir(fullpath, child);	
			continue;
		}
		mapfile(fullpath, child);
	}
}

makedirstat(q: big, src: Sys->Dir): ref Sys->Dir
{
	dirstat := ref src;
	dirstat.qid.path = q;
	dirstat.qid.qtype |= Sys->QTDIR;
	dirstat.mode |= Sys->DMDIR | 8r755;

	return dirstat;
}

makefilestat(q: big, name: string, src: Sys->Dir): ref Sys->Dir
{
	dirstat := ref src;
	dirstat.qid.path = q;
	dirstat.qid.qtype &= ~Sys->QTDIR;
	dirstat.name = name;
	dirstat.mode = 8r644;

	return dirstat;
}

mapfile(path: string, item: ref Direntry)
{
	shaobject := *item.object;
	shaobject.sha1 = path;
	shaobject.otype = "work";
	qid := item.object.dirstat.qid;
	(ret, temp) := sys->stat(path);
	if(ret == -1){
		sys->print("ret is --1 ==>%s\n", path);
		exit;
	}
	shaobject.dirstat = ref temp;
	shaobject.dirstat.qid = qid;
	item.object = ref shaobject;
}

mapworkingtree(path: big)
{
	item := table.find(string path);
	mapfile(repopath[:len repopath-1], item);
	mapdir(item.object.sha1, item);
}

mergelist(l1, l2: list of ref Head): list of ref Head
{
	if(l1 == nil) return l2;

	while(l2 != nil){
		elem := hd l1;
		l := l1;
		while(l != nil){
			if((hd l).name == elem.name) break;
			l = tl l;
		}
		if(l == nil){
			l1 = elem :: l1;
		}
		l2 = tl l2;
	}
	return l1;
}

navigate(navch: chan of ref Navop)
{
mainloop:
	while(1){
		pick navop := <-navch
		{
			Stat =>
				direntry := table.find(string navop.path);
				navop.reply <-= (direntry.getdirstat(), "");	

			Walk =>
				sys->print("NAVOP>WALK\n");
				if(navop.name == ".."){
					ppath := table.find(string navop.path).parent;
					direntry := table.find(string ppath);
					navop.reply <-= (direntry.getdirstat(), nil);
					continue mainloop;
				}

				direntry := table.find(string navop.path);
				if(direntry.object.children == nil){
					sys->print("finding children\n");
					findchildren(navop.path);
				}
				if((ch := child(direntry, navop.name)) != nil){
					navop.reply <-= (ch.getdirstat(), nil);
					continue mainloop;
				}
				navop.reply <-= (nil, "not found");

			Readdir =>
				item := table.find(string navop.path);
				children := findchildren(navop.path);
				sys->print("Readdir child cnt: %d\n", len children);
				while(children != nil && navop.offset-- > 0){
					children = tl children;
				}
				count := navop.count;
				while(children != nil && count-- > 0){					
					sys->print("returning: %s\n", (hd children).getdirstat().name);
					navop.reply <-= ((hd children).getdirstat(), nil);
					children = tl children;
				}
				sys->print("Last line of Readdir\n");
				navop.reply <-= (nil, nil);
		}
	}
}

process(srv: ref Styxserver, tmsgchan: chan of ref Tmsg)
{
mainloop:
	while((gm := <-tmsgchan) != nil){
		pick m := gm{
			Attach =>
				sys->print("PROCESS ATTACH\n");
				rootfid = m.fid;
				srv.default(m);

			Stat => 
				sys->print("PROCESS STAT\n");
				fid := srv.getfid(m.fid); 
				direntry := table.find(string fid.path);
				if(direntry == nil){
					srv.reply(ref Rmsg.Stat(m.tag, sys->nulldir));
				}
				#FIXME: this case isn't needed
				else if(fid.qtype == Sys->QTDIR){
					srv.stat(m);
				}
				else{
					srv.reply(ref Rmsg.Stat(m.tag, *direntry.getdirstat()));
				}

			Create =>
				sys->print("PROCESS CREATE\n");
				fid := srv.getfid(m.fid);
				direntry := table.find(string fid.path);
				sys->print("Creating file: %s in %s\n", m.name, direntry.name);

				if(direntry.object.otype == "index"){
					sys->print("want to create file in index\n");
					#q := QMax++;
					#dirstat := direntry.getdirstat();
					#dirstat = makefilestat(q, m.name, *dirstat);
					#FIXME: temporaily unused code
					#shaobject := ref Shaobject(dirstat, nil, nil, "index", nil);
					#direntry := ref Direntry(q, m.name, shaobject, fid.path);
					#srv.reply(ref Rmsg.Create(m.tag, dirstat.qid, srv.iounit()));
					srv.default(m);
					continue mainloop;
				}

				if(istreedir(direntry)){
					parent := getrecentcommit(fid.path);
					indexpath := getrecentindex(fid.path).path;
					if(parent != workingdir){
						checkout(indexpath, parent);
					}
					fullpath := direntry.getfullpath() + "/" + m.name;
					sys->print("FULLPaTH: %s\n", fullpath);
					(nil, filepath) := stringmod->splitstrr(fullpath,"/tree/");
					sys->print("creating a file: %s\n", repopath + filepath);
					fd := sys->create(repopath + filepath, m.mode, m.perm);
					(ret, dirstat) := sys->fstat(fd);

					sys->print("DIRSTAT NEM: %s\n", dirstat.name);
					#FIXME: should delete old record for the file
					dirstat.qid.path = addentry(direntry.path, dirstat.name, repopath + filepath, ref dirstat, "work");
					sys->print("ATT. QID: %bd\n", dirstat.qid.path);
					srv.reply(ref Rmsg.Create(m.tag, dirstat.qid, srv.iounit()));
					continue mainloop;
				}
				srv.default(m);
	
			Read =>
				sys->print("IN PROCESS READ\n");
				buf: array of byte; ptype: string;
				fid := srv.getfid(m.fid); 
				direntry := table.find(string fid.path);
				parent := table.find(string direntry.parent);
				if(parent != nil)
					ptype = parent.object.otype;

				sys->print("OTYPE: %s\n", direntry.object.otype);
				if(fid.qtype == Sys->QTDIR){
					srv.read(m);
				}
				else if(direntry.object.otype == "log"){
					sys->print("IN READ ==> log\n");
					buf := readlog(direntry.object.sha1, m.offset, m.count);
					if(buf == nil){
						srv.reply(ref Rmsg.Read(m.tag, nil));
						continue mainloop;
					}
					m.offset = big 0;
					srv.reply(styxservers->readbytes(m, buf));
				}
				else{
					if(direntry.object.otype == "work"){
						sys->print("Reading working file: %s\n", direntry.object.sha1);
						buf := array[m.count] of byte;
						fd := sys->open(direntry.object.sha1, Sys->OREAD);
						cnt := sys->read(fd, buf, len buf);
					#FIXME: Uncomment it and make functional
					#	l := readqueries.find(m.tag);
					#	while(l != nil){
					#		if((hd l).fid == m.fid){
					#			(hd l).qdata.data = string buf[:cnt] :: (hd l).qdata.data;
					#			break;	
					#		}
					#		l = tl l;
					#	}
					#	if(l == nil){
					#		readquery := Readquery(m.fid, ref Querydata(string buf[:cnt] :: nil));
					#		oldqueries := readqueries.find(m.tag);
					#		readqueries.del(m.tag);
					#		readqueries.add(m.tag, readquery :: oldqueries);
					#	}	
						if(cnt <= 0){
							srv.reply(ref Rmsg.Read(m.tag, nil));	
						}else{
							srv.reply(styxservers->readbytes(m, buf[:cnt]));
						}
						continue mainloop;
					}
					if(direntry.object.data != nil){
						sys->print("HEYyyA I'm not nil\n");
						srv.reply(styxservers->readbytes(m, direntry.object.data));
						continue mainloop;
					}
					path := direntry.object.sha1;
					catch := chan of array of byte;
					spawn catfilemod->catfile(path, catch);
					buf = <-catch;
					srv.reply(styxservers->readbytes(m, buf));
				}

								

			Write =>
				sys->print("IN PROCESS WRITE\n");
				sys->print("in write\n");
				ptype: string;
				fid := srv.getfid(m.fid);
				cnt := len m.data;
				direntry := table.find(string fid.path);
				filetype := direntry.object.dirstat.qid.qtype;
				parent := table.find(string direntry.parent);
				if(parent != nil)
					ptype = parent.object.otype;
				
				sys->print("ATT. QID: %bd\n", direntry.object.dirstat.qid.path);

				if(direntry.object.otype == "work" && !(filetype & Sys->QTDIR)){
					sys->print("in write work\n");
					sys->print("application data: %s\n", string fid.data);
					sys->print("object.sha1: %s\n", direntry.name);
					fd := sys->open(direntry.object.sha1, Sys->OWRITE | Sys->OTRUNC);	
					sys->seek(fd, m.offset, Sys->SEEKSTART);
					cnt := sys->write(fd, m.data, len m.data);
					sys->print("Write=>, count is %d\n", cnt);
					(nil, dirstat) := sys->fstat(fd);
					direntry.object.dirstat = ref dirstat;
					srv.reply(ref Rmsg.Write(m.tag, cnt));
					continue mainloop;
				}
				if(istreedir(direntry)){
					sys->print("Write istreedir\n");
					parent := getrecentcommit(fid.path);
					indexpath := getrecentindex(fid.path).path;
					if(parent != workingdir){
						checkout(indexpath, parent);
					}
					fullpath := direntry.getfullpath();
					(nil, filepath) := stringmod->splitstrr(fullpath, "/tree/");
					sys->print("opening file: %s == %s\n", filepath, fullpath);
					fd := sys->open(repopath + filepath,  Sys->OWRITE | Sys->OTRUNC);
					sys->seek(fd, m.offset, Sys->SEEKSTART);
					cnt := sys->write(fd, m.data, len m.data);
					sys->print("Write=>, count is %d\n", cnt);
					srv.reply(ref Rmsg.Write(m.tag, cnt));
					continue mainloop;
				}
				#checking whether we're copying the data
				if(direntry.object.otype == "index"){
					queries := readqueries.find(m.tag);
					while(queries != nil){
						query := ref hd queries;
						if(query.contains(string m.data)){
							break;
						}
						queries = tl queries;
					}
					if(queries != nil){
						addfiletoindex(direntry.path, (srv.getfid((hd queries).fid)).path);
					}
				}

				if(ptype == "commit" && direntry.name == "commit_msg"){
					newname := sprint("commit_msg%bd", direntry.path);
					path := mktempfile(newname);
					fd := sys->open(path, Sys->OWRITE);
					sys->seek(fd, m.offset, Sys->SEEKRELA);
					cnt = sys->write(fd, m.data, len m.data);
					direntry.object.otype = "work";
					direntry.object.sha1 = path;
				}
				srv.reply(ref Rmsg.Write(m.tag, cnt));
			
			Walk => 
				sys->print("PROCESS WALK\n");
				fid := srv.getfid(m.fid);
				srv.default(m);

			Remove =>
				fid := srv.getfid(m.fid);
				direntry := table.find(string fid.path);
				sys->print("PROCESS REMOVE: %s\n", direntry.name);
				if(direntry.object.otype == "branch"){
					sys->print("removing branch\n");
					removebranch(direntry);
					srv.reply(ref Rmsg.Remove(m.tag));
					continue mainloop;
				}
				if(direntry.object.otype == "index"){
					parent := table.find(string direntry.parent);
					idir := getrecentindex(fid.path);
					index := indices.find(string idir.path);
					removeindexentry(index, direntry, parent);
					srv.delfid(fid);
					srv.reply(ref Rmsg.Remove(m.tag));
					continue mainloop;
				}
				if(istreedir(direntry)){
					parent := getrecentcommit(fid.path);
					indexpath := getrecentindex(fid.path).path;
					if(parent != workingdir){
						checkout(indexpath, parent);
					}
					#FIXME: should delete removed filed after checkout
				}
				if(direntry.object.otype == "work"){
					if(direntry.getdirstat().mode & Sys->DMDIR){
						removedir(direntry);
					}
					else{
						removefile(direntry);
					}
					srv.delfid(fid);
					srv.reply(ref Rmsg.Remove(m.tag));
					continue mainloop;
				}
				srv.default(gm);

			Wstat =>
				sys->print("IN PROCESS WSTAT\n");
				ptype: string;
				fid := srv.getfid(m.fid);
				direntry := table.find(string fid.path);
				parent := table.find(string direntry.parent);
				if(parent != nil)
					ptype = parent.object.otype;
				if(direntry.object.otype == "work" && m.stat.name == indexkeyword){
					index := getrecentindex(fid.path);
					if(isdir(fid.path)){
						adddirtoindex(index.path, fid.path);
					}
					else{
						addfiletoindex(index.path, fid.path);
					}
					srv.reply(ref Rmsg.Wstat(m.tag));
					continue mainloop;
				}
				if(parent != nil && parent.path == QRoot){
					if(sys->wstat(repopath + ".git/refs/heads/" + direntry.name, m.stat) != -1){
						direntry.name = m.stat.name;
					}
					removehead(direntry.name);
					addhead(direntry.name, direntry.object.sha1);
					srv.reply(ref Rmsg.Wstat(m.tag));
					continue mainloop;
				}

				#parent dir is commit type, renaming tree dir to commit dir
				if(ptype == "commit" && direntry.name == "tree"){
					sys->print("Creating a new commit\n");
					if(m.stat.name != ""){
					#if (m.stat.name == "commit"){
						index := getrecentindex(fid.path);
						printindex(indices.find(string index.path));
						cm := commitmod->readcommit(parent.object.sha1);
						parents := parent.object.sha1 :: nil;
						treesha1 := cm.treesha1;
						if(parent.object.otype == "work"){
							treesha1 = writetree(indices.find(string index.path));
						}
						else{
							parents = cm.parents;
						}
						ch := child(parent, "commit_msg");
						commitfile := ch.object.sha1;
						if(ch.object.otype != "work"){
							sys->print("sha1 of the commit: %s\n", ch.object.sha1);
							sys->print("heee megamsg\n");
							newname := sprint("commit_msg%bd", ch.path);
							path := mktempfile(newname);
							fd := sys->open(path, Sys->OWRITE);
							(nil, nil, filebuf) := utils->readsha1file(ch.object.sha1);
							sys->write(fd, filebuf, len filebuf);
							ch.object.otype = "work";
							ch.object.sha1 = path;
						}
						sys->print("tree sha1: %s\n", treesha1);
						sha1 := committree->commit(treesha1, parents, ch.object.sha1);
						sys->print("commited to: %s\n", sha1);
						dirstat := objectstat(sha1).t1;

						#Updating branch
						path: big;
						fullpath := direntry.getfullpath();
						branchname := basename(fullpath).t0;
						root := table.find(string QRoot);
						branch := child(root, branchname);
						headdir := child(branch, "head");
						(nil, nil, filebuf) := utils->readsha1file(sha1);
						#If we're committing to the non-last commit, then create a new branch
						sys->print("branch object sha1: %s\n", headdir.object.sha1);
						sys->print("parent.object.sha1: %s\n", parent.object.sha1);
						if(headdir.object.sha1 != parent.object.sha1){
							sys->print("BRanching: %s\n", sha1);
							path = addentry(QRoot, m.stat.name, nil, makedirstat(QMax++, dirstat), "branch");
							head := ref Head(m.stat.name, sha1);
							addheadfile(m.stat.name, sha1);
							addbranch(path, dirstat, head);
						}
						else{
							path = addentry(branch.path, "head", sha1, makedirstat(QMax++, dirstat), "commit");
							parent.name = "parent1";
							parent.parent = path;
							removechild(branch, parent.path);
							updatehead(branchname, sha1);
							readchildren(sha1, path);
						}
						#restoring prev commit msg for parent
						ch.object.otype = "commit";
						ch.object.sha1 = parent.object.sha1;
						catch := chan of array of byte;
						spawn catfilemod->catfile(ch.object.sha1, catch);
						ch.object.data = <-catch;
						tree := child(parent, "tree");
						treedir := table.find(string tree.path);
						treedir.object.children = nil;
						treedir.object.otype = "tree";
						treedir.object.sha1 = cm.treesha1;
						srv.reply(ref Rmsg.Wstat(m.tag));
						spawn chdir();
						continue mainloop;
					}
#					else{
#						dirstat := objectstat(parent.object.sha1).t1;
#						path := addentry(QRoot, m.stat.name, parent.object.sha1, makedirstat(QMax++, dirstat), "commit");
#						head := ref Head(m.stat.name, parent.object.sha1);
#						addheadfile(m.stat.name, parent.object.sha1);
#						addbranch(path, dirstat, head);
#						srv.reply(ref Rmsg.Wstat(m.tag));
#						continue mainloop;
#					}
				}
				srv.default(m);

			Clunk =>
				sys->print("IN PROCESS CLUNK\n");
				fid := srv.getfid(m.fid);
				if(m.fid == rootfid){
					sys->print("Unmounting\n");
					indlist := indices.all();
					while(indlist != nil){
						writeindex(hd indlist);
						indlist = tl indlist;
					}
				}

#FIXME: add code for removing old readqueries
#				queries := readqueries.find(m.tag);
#				newqueries: list of Readmdata;
#				found := 0;
#				while(queries != nil){
#					query := hd queries;
#					queries = tl queries;
#					if(query.fid == m.fid){
#						found = 1;
#						continue;
#					}
#					newqueries = query :: newqueries;
#				}
#
#				if(found){
#					readqueries.del(m.tag);
#					readqueries.add(m.tag, newqueries);
#				}
				srv.default(m);

			* => srv.default(gm);
		}
	}
}

isdir(path: big): int
{
	direntry := table.find(string path);
	return direntry.object.dirstat.qid.qtype == Sys->QTDIR;
}

isrenaming(oldstat, stat: ref Sys->Dir): int
{
	sys->print("NAME; %s == %s\n", oldstat.name, stat.name);
	return oldstat.name != stat.name;
#	return oldstat.name != stat.name
#            && oldstat.uid  == stat.uid
#	    && oldstat.gid  == stat.gid
#	    && oldstat.mode == stat.mode
#	    && oldstat.length == stat.length;
}

readchildren(sha1: string, parentqid: big)
{
	sys->print("in read children: %s\n", sha1);
	parent := table.find(string parentqid);
	(filetype, filesize, filebuf) :=  utils->readsha1file(sha1);
	if(filetype == "commit"){
		commit := readcommitbuf(sha1, filebuf);
		q := QMax++;
		dirstat := objectstat(commit.treesha1).t1;
		shaobject := shatable.find(commit.treesha1);
		if(shaobject == nil){
			shaobject = ref Shaobject(makedirstat(q, dirstat), nil, commit.treesha1, "tree", nil);
			shatable.add(shaobject.sha1, shaobject);
		}
		direntry := ref Direntry(q, parent.path, "tree", shaobject);
		parent.object.children = direntry.path :: parent.object.children;
		table.add(string direntry.path, direntry);
		parents := ""; pnum := 1;
		l := commit.parents;
		while(l != nil){
			psha1 := hd l;
			q = QMax++;
			name := "parent" + string pnum++;
			dirstat = objectstat(psha1).t1;
			shaobject = shatable.find(psha1);
			if(shaobject == nil){
				shaobject = ref Shaobject(makedirstat(q, dirstat), nil, psha1, "commit", nil);
				shatable.add(psha1, shaobject);
			}
			direntry = ref Direntry(q, parent.path, name, shaobject);
			table.add(string direntry.path, direntry) ;
			parent.object.children = direntry.path :: parent.object.children;
			l = tl l;
		}
		createlogstat(parent, ref dirstat, commit.comment);
	}
	else if(filetype == "tree"){
		tree := readtreebuf(sha1, filebuf);
		l := tree.children;
		while(l != nil){
			q := QMax++;
			item := hd l;
			shaobject := shatable.find(item.t2);
			if(shaobject == nil){
				dirstat := objectstat(item.t2).t1; 
				shaobject = ref Shaobject(ref dirstat, nil, item.t2, "blob", nil);
				shatable.add(item.t2, shaobject);
			}
			shaobject.dirstat.mode = 8r644;
			if(utils->isunixdir(item.t0)){
				sys->print("TREE DIR ENTRY: %s\n", item.t1);
				shaobject.dirstat = makedirstat(q, *shaobject.dirstat);
				shaobject.children = nil;
				shaobject.otype = "tree";
				shaobject.sha1 = item.t2;
			}
			direntry := ref Direntry(q, parent.path, item.t1, shaobject);
			table.add(string direntry.path, direntry);
			parent.object.children = direntry.path :: parent.object.children;
			l = tl l;
		}
	}
}

readheads(path, prefix: string): list of ref Head
{
	heads: list of ref Head = nil;
	(dirs, nil) := readdir->init(path, Readdir->NAME);
	for(i := 0; i < len dirs; i++){
		fpath := path + "/" + dirs[i].name;
		if(dirs[i].qid.qtype & Sys->QTDIR){
			heads = lists->concat(readheads(fpath, dirs[i].name + "+"), heads);
			continue;
		}
		ibuf := bufio->open(fpath, Bufio->OREAD);
		if(ibuf == nil){
			error(sprint("ibuf is nil; path is %s\n", path + "/" + dirs[i].name));
			continue;
		}
		sha1 := strip(ibuf.gets('\n'));
		head := ref Head(prefix + dirs[i].name, sha1);
		heads = head :: heads;
	}
	
	return heads;
}

readlog(head: string, moffset: big, mcount: int): array of byte
{
	sys->print("IN READLOG\n");
	logch := chan of array of byte;
	spawn log->readlog(head, logch);
	offset := moffset; temp: array of byte;
	while(offset > big 0){
		temp = <-logch;
		offset -= big len temp;
	}
	if(moffset != big 0 && temp == nil){
		return nil;
	}
	buf := array[0] of byte;
	#If we preread more then we need(i.e offset is shifted more), we should rewind buf
	count := mcount;
	if(offset < big 0){
		buf = array[int -offset] of byte;
		buf[:] = temp[len temp + int offset:];
		count -= len buf;
	}
	while(count > 0){
		temp = <-logch;
		if(temp == nil)
			break;
		oldbuf := buf[:];
		buf = array[len oldbuf + len temp] of byte;
		buf[:] = oldbuf;
		buf[len oldbuf:] = temp;
		count -= len temp;
	}

	return buf;
}

readpackedheads(): list of ref Head
{
	l: list of ref Head;
	ibuf := bufio->open(repopath + ".git/packed-refs", Sys->OREAD);
#	sys->print("path==%s\n", repopath + "packed-refs");
	if(ibuf != nil){
		while((s := ibuf.gets('\n')) != nil){
#FIXME: should add code for processing packed-refs traits
			sys->print("==>%s\n", s);
			if(s[0] == '#') continue;
			(s1, s2) := stringmod->splitl(s, " ");	
			s2 = s2[1:len s2 - 1];
			(nil, s2) = stringmod->splitstrr(s2, "heads/");
			s2 = utils->replacechar(s2, '/', '+');
			head := ref Head(s2, s1);
			l = head :: l;
		}
	}
	return l;
}

Readquery.contains(readquery: self ref Readquery, s: string): int
{
	data := readquery.qdata.data;
	while(data != nil){
		if(hd data == s)
			return 1;
		data = tl data;
	}

	return 0;
}

Readquery.eq(a, b: ref Readquery): int
{
	return a.fid == b.fid && a.qdata == b.qdata;
}

removebranch(direntry: ref Direntry)
{
	if(len heads == 1) return;
	sys->remove(repopath + ".git/refs/heads/" + direntry.name);
	l := direntry.object.children;
	while(l != nil){
		removeentry(hd l);
		l = tl l;
	}
	h := heads;
	heads = nil;
	while(h != nil){
		if(direntry.object.sha1 != (hd h).sha1){
			heads = (hd h) :: heads;
		}
		h = tl h; 
	}
	removeentry(direntry.path);	
}

removechild(parent: ref Direntry, path: big)
{
	sys->print("IN REMOVECHILD\n");
	sys->print("PARENT: %s\n", parent.name);
	sys->print("CHILD: %s\n", table.find(string path).name);
	children: list of big;
	l := parent.object.children;
	while(l != nil){
		if(hd l != path){
			children = hd l :: children;
		}
		l = tl l;
	}
	sys->print("in removechild: ==>%d==%d\n", len children, len parent.object.children);
	parent.object.children = children;
}

removedir(direntry: ref Direntry)
{
	l := direntry.object.children;
	while(l != nil){
		child := table.find(string hd l);
		removefile(child);
		l = tl l;
	}
	removefile(direntry);
}

removeentry(path: big)
{
	item := table.find(string path);
	if(item != nil){
		table.del(string item.path);
		#FIXME: entries of shatable is reused, so code for removing gently should be add
		#shatable.del(item.object.sha1);
		children := item.object.children;
		while(children != nil){
			removeentry(hd children);
			children = tl children;
		}
	}
}

removefile(direntry: ref Direntry)
{
	sys->print("removing file: %s == %s\n", direntry.name, direntry.object.sha1);
	if(direntry.object.otype != "work"){
		sys->remove(string2path(direntry.object.sha1));
	}
	else{
		sys->remove(direntry.object.sha1);
	}
	parent := table.find(string direntry.parent); 
	removechild(parent, direntry.path);
	removeentry(direntry.path);
}

removehead(name: string)
{
	l: list of ref Head;
	while(heads != nil){
		if((hd l).name != name)
			l = hd heads :: l;
		heads = tl heads;
	}
	heads = l;
}

removeindexentry(index: ref Index, direntry, parent: ref Direntry)
{
	dirstat := direntry.getdirstat();
	if(dirstat.mode & Sys->DMDIR){
		l := direntry.object.children;
		while(l != nil){
			child := table.find(string hd l);
			removeindexentry(index, child, direntry);
			l = tl l;
		}
	}
	else{
		(nil, filepath) := stringmod->splitstrr(direntry.getfullpath(),"index/");
		index.rmfile(filepath);
	}
	removechild(parent, direntry.path);
	removeentry(direntry.path);
}

updatehead(branch, sha1: string)
{
	sys->print("updatehead: branch = %s; sha1 = %s\n", branch, sha1);
	fullpath := repopath + ".git/refs/heads/" + branch;
	fd := sys->open(fullpath, Sys->OWRITE);
	if(fd == nil)
		fd = sys->create(fullpath, Sys->OWRITE, 8r644);

	if(fd != nil){
		buf := array of byte (sha1 + "\n");
		sys->write(fd, buf, len buf);
	}
}

usage()
{
	sys := load Sys Sys->PATH;
	sys->fprint(sys->fildes(1), "mount {git/gitfs dir} mntpt");
	exit;
}
