implement Gitfs;

include "mods.m";
mods: Mods;
include "modules.m";

print, sprint: import sys;
Tmsg, Rmsg: import styx;
Fid, Navop, Navigator, Styxserver: import styxservers;
readcommitbuf, Commit: import commitmod;
readindex, writeindex, Entry, Header, Index: import gitindex;
readtreebuf, Tree: import treemod;
basename, cleandir, makeabsentdirs, makepathabsolute, string2path, INDEXPATH, HEADSPATH, OBJECTSTOREPATH: import pathmod;	
readtree: import readtreemod;	
bufsha1, debugmsg, error, sha2string, splitl, SHALEN: import utils;
writetree: import writetreemod;	

include "gitfs.m";

QRoot, QRootCtl, QRootData, QRootLog, QRootConfig, QRootExclude, QRootObjects, 
QRootFiles, QIndex, QIndex1, QIndex2, QIndex3, QStaticMax: con big iota;

QMax := QStaticMax;

INITSIZE: con 17;

arglist: list of string;
commitmsg: array of byte;
debug: int;
heads: list of ref Head;
nav: ref Navigator;
readqueries: ref Table[list of Readquery];
srv: ref Styxserver;
rootfid: int;
table: ref Strhash[ref Direntry];
workingdir: ref Direntry;

cwd, ppwd: big;

init(nil: ref Draw->Context, args: list of string)
{
	mods = load Mods Mods->PATH;

#	if(len args < 2)
#		usage();
#	
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
	index = Index.new(arglist, debug);
	readindex(index);

	sys->pctl(Sys->NEWPGRP, nil);
	inittable();

	checkoutmod->init(mods);

	styx->init();
	styxservers->init(styx);
	styxservers->traceset(1);
	navch := chan of ref Navop;
	nav = Navigator.new(navch);
	spawn navigate(navch);
	tmsgchan: chan of ref Tmsg;
	(tmsgchan, srv) = Styxserver.new(sys->fildes(0), nav, big QRoot);
	spawn process(srv, tmsgchan);
}

initmodules()
{
	catfilemod->init(mods);
	checkoutmod->init(mods);
	commitmod->init(mods);
	committree->init(mods);
	gitindex->init(mods);
	log->init(mods);
	pathmod->init(mods);
	repo->init(mods);
	treemod->init(mods);
	readtreemod->init(mods);
	utils->init(mods);
	writetreemod->init(mods);
}



inittable()
{
	table = Strhash[ref Direntry].new(INITSIZE, nil);
	shatable = Strhash[ref Shaobject].new(INITSIZE, nil);
	readqueries = Table[list of Readquery].new(INITSIZE, nil);
	
	direntry: ref Direntry;
	dirstat: Sys->Dir;
	l: list of big;
	ret: int;
	shaobject: ref Shaobject;
	
	heads = heads1 := readheads(repopath + HEADSPATH, "");
	while(heads1 != nil){
		head := hd heads1;
		(ret, dirstat) = sys->stat(string2path(head.sha1));
		if(ret == -1){
			error(sprint("head %s couldn't be accessed\n", string2path(head.sha1)));
			continue;
		}
		q := QMax++;
		l = q :: l;
		shaobject = ref Shaobject(makedirstat(q, dirstat), nil, head.sha1, "commit", nil);
		direntry = ref Direntry(q, head.name, shaobject, QRoot);
		table.add(string direntry.path, direntry);
		shatable.add(shaobject.sha1, shaobject);
		heads1 = tl heads1;
	}

	shaobject = ref Shaobject(makedirstat(QRoot, dirstat), QIndex :: l, nil, nil, nil);
	direntry = ref Direntry(QRoot, ".", shaobject, big -1);
	table.add(string direntry.path, direntry);

	initindex();
}

readheads(path, prefix: string): list of ref Head
{
	shas: list of ref Head = nil;
	(dirs, nil) := readdir->init(path, Readdir->NAME);
	for(i := 0; i < len dirs; i++){
		if(dirs[i].qid.qtype & Sys->QTDIR){
			shas = lists->concat(readheads(path + "/" + dirs[i].name, dirs[i].name + "+"), shas);
			continue;
		}
		ibuf := bufio->open(path + "/" + dirs[i].name, Bufio->OREAD);
		if(ibuf == nil){
			error(sprint("ibuf is nil; path is %s\n", path + "/" + dirs[i].name));
			continue;
		}
		sha1 := ibuf.gets('\n');
		if(sha1 != nil && sha1[len sha1 - 1] == '\n')
			sha1 = sha1[:len sha1 - 1];
		head := ref Head(prefix + dirs[i].name, sha1);
		shas = head :: shas;
	}
	
	return shas;
}

initindex()
{
	#Adding index/ and subdirs
	(ret, dirstat) := sys->stat(repopath + INDEXPATH);
	if(ret == -1)
		error(sprint("Index file at %s is not found\n", repopath + INDEXPATH));

	dirstat = *makedirstat(QIndex, dirstat);
	shaobject := ref Shaobject(ref dirstat, QIndex1 :: (QIndex2 :: (QIndex3 :: nil)), nil, "index", nil);
	extractindexstage(shaobject, "index", QRoot, 0);

	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	extractindexstage(shaobject, "1", QIndex, 1);

	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	extractindexstage(shaobject, "2", QIndex, 2);
	
	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	extractindexstage(shaobject, "3", QIndex, 3);

}

extractindexstage(shaobject: ref Shaobject, name: string, ppath: big, stage: int)
{
	direntry := ref Direntry(QIndex + big stage, name, shaobject, ppath);
	table.add(string direntry.path, direntry);
	fillindexdir(direntry, stage);
}

removechild(parent: ref Direntry, path: big)
{
	children: list of big;
	l := parent.object.children;
	while(l != nil){
		if(hd l == path){
			l = tl l;
			continue;
		}
		children = hd l :: children;
		l = tl l;
	}
	parent.object.children = children;
}


removeentry(path: big)
{
	item := table.find(string path);
	if(item != nil){
		table.del(string item.path);
		#entries of shatable is reused, so code for removing gently should be add
		#shatable.del(item.object.sha1);
		children := item.object.children;
		while(children != nil){
			removeentry(hd children);
			children = tl children;
		}
	}
}

fillindexdir(parent: ref Direntry, stage: int)
{
	dirstat := sys->stat(repopath + INDEXPATH).t1;
	direntry: ref Direntry;
	shaobject: ref Shaobject;

	ppath := QIndex + big stage;
	oldpath := ppath;
	oldparent := parent;
	entries := index.getentries(stage);
	while(entries != nil){
		entry := hd entries;
		sha1 := sha2string(entry.sha1);
		q := QMax++;
		parent = oldparent;

		name: string;
		(q, parent, name) = makeabsententries(q, parent, entry.name, dirstat);

		dirstat = sys->stat(string2path(sha1)).t1;
		dirstat.mode = 8r644;
		shaobject = ref Shaobject(ref dirstat,nil,  sha1, "index", nil);
		direntry = ref Direntry(q, name, shaobject, parent.path);
		parent.object.children = direntry.path :: parent.object.children;
		table.add(string direntry.path, direntry);
		shatable.add(sha1, shaobject);

		entries = tl entries;
	}
}

makeabsententries(q: big, parent: ref Direntry, name: string, dirstat: Sys->Dir): (big, ref Direntry, string)
{
	(dirname, rest) := basename(name);
	while(dirname != nil){
		child := child(parent, dirname);
		if(child == nil){
			shaobject := ref Shaobject(makedirstat(q, dirstat), nil, nil, "index", nil); 
			child = ref Direntry(q, dirname, shaobject, parent.path);
			table.add(string child.path, child);
			parent.object.children = child.path :: parent.object.children;
		}
		parent = child;
		q = QMax++;
		(dirname, rest) = basename(rest);
	}

	return (q, parent, rest);
}

mapworkingtree(path: big)
{
	item := table.find(string path);
	sha1 := item.object.sha1;
	mapfile(repopath[:len repopath-1], item);
	mapdir(item.object.sha1, item);
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

mapfile(path: string, item: ref Direntry)
{
	shaobject := *item.object;
	shaobject.sha1 = path;
	shaobject.otype = "work";
	qid := item.object.dirstat.qid;
	(ret, temp) := sys->stat(path);
	shaobject.dirstat = ref temp;
	if(ret == -1){
		sys->print("ret is --1 ==>%s\n", path);
		exit;
	}
	shaobject.dirstat.qid = qid;
	item.object = ref shaobject;
}

child(parent: ref Direntry, name: string): ref Direntry
{
	ret: ref Direntry;
	l := parent.object.children;
	while(l != nil){
		ret = table.find(string hd l);
		if(ret != nil && ret.name == name)
		{
			return ret;
		}
		l = tl l;
	}
	
	return nil;
}

process(srv: ref Styxserver, tmsgchan: chan of ref Tmsg)
{
mainloop:
	while((gm := <-tmsgchan) != nil){
		pick m := gm{
			Attach =>
				rootfid = m.fid;
				srv.default(m);
			Stat => 
				fid := srv.getfid(m.fid); 
				direntry := table.find(string fid.path);
				if(direntry == nil || fid.qtype == Sys->QTDIR){
					srv.stat(m);
					continue mainloop;
				}
				srv.reply(ref Rmsg.Stat(m.tag, *direntry.getdirstat()));

			Create =>
				fid := srv.getfid(m.fid);
				direntry := table.find(string fid.path);
				if(direntry.object.otype == "index"){
					q := QMax++;
					dirstat := direntry.getdirstat();
					dirstat = makefilestat(q, m.name, *dirstat);
					shaobject := ref Shaobject(dirstat, nil, nil, "index", nil);
					direntry := ref Direntry(q, m.name, shaobject, fid.path);
					srv.reply(ref Rmsg.Create(m.tag, dirstat.qid, srv.iounit()));
					continue mainloop;
				}
				if(istreedir(direntry)){
					parent := getrecentcommit(fid.path);
					if(parent != workingdir){
						checkout(parent, direntry);
					}
					fullpath := direntry.getfullpath() + "/" + m.name;
					(nil, filepath) := stringmod->splitstrr(fullpath,"/tree/");
					fd := sys->create(repopath + filepath, m.mode, m.perm);
					(ret, dirstat) := sys->fstat(fd);

					q := QMax++;
					dirstat.qid.path = q;
					shaobject := ref Shaobject(ref dirstat, nil, repopath + filepath, "work", nil);
					direntry1 := ref Direntry(q, m.name, shaobject, direntry.path);
					table.add(string direntry1.path, direntry1);
					direntry.object.children = direntry1.path :: direntry.object.children;
					fid.path = direntry1.path;
					srv.reply(ref Rmsg.Create(m.tag, dirstat.qid, srv.iounit()));
					continue mainloop;
				}
				srv.default(m);
	
			Read =>
				fid := srv.getfid(m.fid); 
				direntry := table.find(string fid.path);
				buf: array of byte;
				parent := table.find(string direntry.parent);
				ptype: string;
				if(parent != nil)
					ptype = parent.object.otype;

				if(fid.qtype == Sys->QTDIR){
					srv.read(m);
				}
				else if(ptype == "commit" && direntry.name == "log"){
					logch := chan of array of byte;
					head := direntry.object.sha1; 

					spawn log->readlog(head, logch);

					offset := m.offset;
					temp: array of byte;
					while(offset > big 0){
						temp = <-logch;
						offset -= big len temp;
					}
					if(m.offset != big 0 && temp == nil){
						srv.reply(ref Rmsg.Read(m.tag, nil));
						continue mainloop;
					}
					buf = array[0] of byte;
					#If we preread more then we need(i.e offset is shifted more), we should rewind buf
					count := m.count;
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
					m.offset = big 0;
					srv.reply(styxservers->readbytes(m, buf));
				}
				else{
	
					if(direntry.object.otype == "work"){
						buf := array[m.count] of byte;
						fd := sys->open(direntry.object.sha1, Sys->OREAD);
						cnt := sys->read(fd, buf, len buf);

						l := readqueries.find(m.tag);
	
						while(l != nil){
							if((hd l).fid == m.fid){
								(hd l).qdata.data = string buf[:cnt] :: (hd l).qdata.data;
								break;	
							}
							l = tl l;
						}
						if(l == nil){
							readquery := Readquery(m.fid, ref Querydata(string buf[:cnt] :: nil));
							oldqueries := readqueries.find(m.tag);
							readqueries.del(m.tag);
							readqueries.add(m.tag, readquery :: oldqueries);
						}	
						srv.reply(styxservers->readbytes(m, buf[:cnt]));
						continue mainloop;
					}

					if(direntry.object.data != nil){
						srv.reply(styxservers->readbytes(m, direntry.object.data));
						continue mainloop;
					}
	
					path := direntry.object.sha1;
					catch := chan of array of byte;
					
					spawn catfilemod->catfile(path, catch);

					#reading filetype
					#<-catch;
					buf = <-catch;
					srv.reply(styxservers->readbytes(m, buf));
				}

								

			Write =>
				fid := srv.getfid(m.fid);
				cnt := len m.data;
				direntry := table.find(string fid.path);
				parent := table.find(string direntry.parent);
				ptype: string;
				if(parent != nil)
					ptype = parent.object.otype;

				if(direntry.object.otype == "work"){
					fd := sys->open(direntry.object.sha1, Sys->OWRITE);	
					sys->seek(fd, m.offset, Sys->SEEKSTART);
					cnt := sys->write(fd, m.data, len m.data);
					(nil, dirstat) := sys->fstat(fd);
					direntry.object.dirstat = ref dirstat;
					srv.reply(ref Rmsg.Write(m.tag, cnt));
					continue mainloop;
				}
				if(istreedir(direntry)){
					parent := getrecentcommit(fid.path);
					if(parent != workingdir){
						checkout(parent, direntry);
					}
					fullpath := direntry.getfullpath();
					(nil, filepath) := stringmod->splitstrr(fullpath, "/tree/");
					fd := sys->open(repopath + filepath, Sys->OWRITE);
					sys->seek(fd, m.offset, Sys->SEEKSTART);
					cnt := sys->write(fd, m.data, len m.data);
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
						sys->print("Adding to index\n");
						fid := srv.getfid((hd queries).fid);
						direntry1 := table.find(string fid.path);
						sys->print("adding file %s to index\n", direntry1.getfullpath());
						sha1 := index.addfile(direntry1.getfullpath());

						parent := direntry;
						while(!(parent.object.dirstat.mode & Sys->DMDIR)){
							parent = table.find(string parent.parent);
						}
						(nil, direntry1.name) = stringmod->splitstrr(direntry1.getfullpath(),"/tree/");
						q := q1 := QMax++;
						if((child := child(parent, direntry1.name)) != nil){
							removechild(parent, child.path);
							removeentry(child.path);
						}
						(q, parent, direntry1.name) = makeabsententries(q, parent, direntry1.name, *direntry1.object.dirstat);

						#If no parents were absent we should decrement QMax to avoid junk qid.path
						if(q == q1) QMax--;
						#removeentry(QIndex);
						#initindex();
						path := addentry(parent.path, direntry1.name, sha1, direntry1.object.dirstat, "index");
					}
					else{
						#hd queries;
					}
				}

				if(ptype == "commit" && direntry.name == "commit_msg"){
					oldcommitmsg := commitmsg;
					commitmsg = array[len oldcommitmsg + len m.data] of byte;
					commitmsg[:] = oldcommitmsg;
					commitmsg[len oldcommitmsg:] = m.data;
				}
				srv.reply(ref Rmsg.Write(m.tag, cnt));
			
			Walk => 
				fid := srv.getfid(m.fid);
				srv.default(m);

			Remove =>
				fid := srv.getfid(m.fid);
				direntry := table.find(string fid.path);
				if(direntry.object.otype == "index"){
					sys->print("removing entry from index\n");
					parent := table.find(string direntry.parent);
					(nil, filepath) := stringmod->splitstrr(direntry.getfullpath(),"index/");
					removeindexentry(direntry, parent);
					srv.delfid(fid);
					srv.reply(ref Rmsg.Remove(m.tag));
					continue mainloop;
				}
				else if(istreedir(direntry)){
					parent := getrecentcommit(fid.path);
					if(parent != workingdir){
						checkout(parent, direntry);
					}
				}
				if(direntry.object.otype == "work"){
					sys->print("removing from working dir\n");
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
				fid := srv.getfid(m.fid);
				direntry := table.find(string fid.path);
				parent := table.find(string direntry.parent);
				ptype: string;
				if(parent != nil)
					ptype = parent.object.otype;
				
				#parent dir is commit type, renaming tree dir to commit dir
				if(ptype == "commit" &&  direntry.name == "tree" && m.stat.name == "commit"){
					treesha1 := writetree(index);
					sha1 := committree->commit(treesha1, parent.object.sha1 :: nil, string commitmsg);
					sys->print("commited to: %s\n", sha1);
					commitmsg = nil;
					srv.reply(ref Rmsg.Wstat(m.tag));
					continue mainloop;
				}

				srv.default(m);

			Clunk =>
				fid := srv.getfid(m.fid);
				if(m.fid == rootfid){
					writeindex(index);
				}
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

printlistofstring(l: list of string)
{
	sys->print("-------------------\n");
	while(l != nil){
		sys->print("===>%s\n", hd l);
		l = tl l;
	}
	sys->print("-------------------\n");
}

removefile(direntry: ref Direntry)
{
	sys->print("removing file: %s\n", direntry.object.sha1);
	sys->remove(direntry.object.sha1);
	parent := table.find(string direntry.parent); 
	removechild(parent, direntry.path);
	removeentry(direntry.path);
}

removedir(direntry: ref Direntry)
{
	sys->print("removing dir: %s\n", direntry.name);
	l := direntry.object.children;
	while(l != nil){
		child := table.find(string hd l);
		removefile(child);
		l = tl l;
	}
	removefile(direntry);
}


removeindexentry(direntry, parent: ref Direntry)
{
	dirstat := direntry.getdirstat();
	if(dirstat.mode & Sys->DMDIR){
		l := direntry.object.children;
		while(l != nil){
			child := table.find(string hd l);
			removeindexentry(child, direntry);
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

checkout(parent: ref Direntry, direntry: ref Direntry)
{
	cleandir(repopath[:len repopath-1]);
	index = checkoutmod->checkout(parent.object.sha1);
	l1 := index.entries.all();
	pp := hd l1;
	removeentry(QIndex);
	initindex();
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

addentry(ppath: big, name, sha1: string, dirstat: ref Sys->Dir, otype: string): big 
{
	path := QMax++;
	shaobject := ref Shaobject(dirstat, nil, sha1, otype, nil);
	direntry := ref Direntry(path, name, shaobject, ppath);

	table.add(string direntry.path, direntry);
	if(sha1 != nil)
		shatable.add(shaobject.sha1, shaobject);
	
	parent := table.find(string ppath);
	parent.object.children = path :: parent.object.children;

	return direntry.path;
}

navigate(navch: chan of ref Navop)
{
mainloop:
	while(1){
		pick navop := <-navch
		{
			Stat =>
				debugmsg("in stat:\n");
				if(navop.path == big QRoot)
					;#
				direntry := table.find(string navop.path);
			
				navop.reply <-= (direntry.getdirstat(), "");	

			Walk =>
				debugmsg(sprint("in walk: %s\n", navop.name));
				if(navop.name == ".."){
					ppath := table.find(string navop.path).parent;
					direntry := table.find(string ppath);
					navop.reply <-= (direntry.getdirstat(), nil);
					ppwd = cwd;
					cwd = ppath;
					continue mainloop;
				}
			
				for(l := findchildren(navop.path); l != nil; l = tl l){
					debugmsg("navigate/walk forloop\n");
					direntry := hd l;
					dirstat := direntry.getdirstat();
					#DELME:
					if(dirstat == nil)
					{
						dirstat = ref sys->stat(string2path(direntry.object.sha1)).t1;
					}

					name1 := dirstat.name;
					name2 := navop.name;
					if(dirstat.name == navop.name){
						if(dirstat.qid.qtype & Sys->QTDIR){
							debugmsg("dir is matched\n");
							ppwd = cwd;
							cwd = navop.path;
						}
						navop.reply <-= (dirstat, nil);
						continue mainloop;
					}
				}
				navop.reply <-= (nil, "not found");

			Readdir =>
				debugmsg(sprint("in readdir: %bd\n", navop.path));
				item := table.find(string navop.path);
				if(item.object.otype == "work" ){

				}
				children := findchildren(navop.path);
				while(children != nil && navop.offset-- > 0){
					children = tl children;
				}
				count := navop.count;
				while(children != nil && count-- > 0){					
					navop.reply <-= ((hd children).getdirstat(), nil);
					children = tl children;
				}
				navop.reply <-= (nil, nil);
		}
	}
}

min(a, b: int): int
{
	if(a < b) return a;
	return b;
}

usage()
{
	error("mount {myfs dir} mntpt");
	exit;
}

readchildren(sha1: string, parentqid: big)
{
	(filetype, filesize, filebuf) :=  utils->readsha1file(sha1);
	parent := table.find(string parentqid);
	if(filetype == "commit"){
		commit := readcommitbuf(sha1, filebuf);
		q := QMax++;
		shaobject := shatable.find(commit.treesha1);
		dirstat := (sys->stat(string2path(commit.treesha1))).t1;
		if(shaobject == nil){
			shaobject = ref Shaobject(makedirstat(q, dirstat), nil, commit.treesha1, "tree", nil);
			shatable.add(shaobject.sha1, shaobject);
		}
		direntry := ref Direntry(q, "tree", shaobject, parent.path);
		table.add(string direntry.path, direntry);
		parent.object.children = direntry.path :: parent.object.children;

		parents := "";
		pnum := 1;
		l := commit.parents;
		while(l != nil){
			psha1 := hd l;
			l = tl l;
			q = QMax++;
			name := "parent" + string pnum++;
			dirstat = (sys->stat(string2path(psha1))).t1;
			shaobject = shatable.find(psha1);
			if(shaobject == nil){
				shaobject = ref Shaobject(makedirstat(q, dirstat), nil, psha1, "commit", nil);
				shatable.add(psha1, shaobject);
			}
			direntry = ref Direntry(q, name, shaobject, parent.path);

			table.add(string direntry.path, direntry) ;
			parent.object.children = direntry.path :: parent.object.children;
		}

		createlogstat(parent, ref dirstat, commit.comment);
	}
	else if(filetype == "tree"){
		debugmsg("file tteee\n");
		tree := readtreebuf(sha1, filebuf);

		l := tree.children;
		while(l != nil){
			item := hd l;
			l = tl l;
			q := QMax++;
			shaobject := shatable.find(item.t2);
			if(shaobject == nil){
				dirstat := sys->stat(string2path(item.t2)).t1; 
				shaobject = ref Shaobject(ref dirstat, nil, item.t2, "blob", nil);
				shatable.add(item.t2, shaobject);
			}
			shaobject.dirstat.mode = 8r644;
			if(utils->isunixdir(item.t0)){
				shaobject.dirstat = makedirstat(q, *shaobject.dirstat);
			}
			direntry := ref Direntry(q, item.t1, shaobject, parent.path);
			table.add(string direntry.path, direntry);
			parent.object.children = direntry.path :: parent.object.children;
		}
	}
}

createlogstat(parent: ref Direntry, dirstat: ref Sys->Dir, msg: string)
{
	q := QMax++;
	dirstat.mode = 8r644;
	shaobject := ref Shaobject(dirstat, nil, nil, nil, sys->aprint("%s", msg));
	direntry := ref Direntry(q, "commit_msg", shaobject, parent.path);
	table.add(string direntry.path, direntry);
	parent.object.children = direntry.path :: parent.object.children;

	#Adding log entry
	q = QMax++;
	shaobject.data = nil;
	shaobject.sha1 = parent.object.sha1;
	direntry = ref Direntry(q, "log", shaobject, parent.path);
	table.add(string direntry.path, direntry);
	parent.object.children = direntry.path :: parent.object.children;

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

makedirstat(q: big, src: Sys->Dir): ref Sys->Dir
{
	dirstat := ref src;
	dirstat.qid.path = q;
	dirstat.qid.qtype |= Sys->QTDIR;
	dirstat.mode |= Sys->DMDIR | 8r755;

	return dirstat;
}

istreedir(direntry: ref Direntry): int
{
	fullpath := direntry.getfullpath();
	underbranch := 0;
	(s, nil) := stringmod->splitl(fullpath, "/");
	l := heads;
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

getrecentcommit(path: big): ref Direntry
{
	parent: ref Direntry;
	do{
		parent = table.find(string path);
		path = parent.parent;

	}while(parent.object.otype != "commit");

	return parent;
}

Direntry.getfullpath(direntry: self ref Direntry): string
{
	ret := direntry.getdirstat().name; 
	direntry = table.find(string direntry.parent);
	while(direntry != nil && direntry.path != QRoot){
		ret = sprint("%s/%s",direntry.getdirstat().name, ret);	
		direntry = table.find(string direntry.parent);
	}

	return ret;

}

findchildren(ppath: big): list of ref Direntry 
{
	direntry := table.find(string ppath);
	if(direntry == nil)	
		return nil;

	if(direntry.object.children == nil && (ppath < QIndex || ppath > QIndex3)){
		debugmsg(sprint("not filled %bd\n", ppath));
		readchildren(direntry.object.sha1, ppath);
	}

	children: list of ref Direntry;
	l := direntry.object.children;
	while(l != nil){
		dentry := table.find(string hd l);
		if(dentry != nil){
			children = dentry :: children; 
		}

		l = tl l;
	}
	debugmsg(sprint("returning from findchildren %d; pwd is %bd\n", len children, ppath));
	return children; 
}

Readquery.eq(a, b: ref Readquery): int
{
	return a.fid == b.fid && a.qdata == b.qdata;

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

Direntry.getdirstat(direntry: self ref Direntry): ref Sys->Dir
{
	ret := *direntry.object.dirstat;
	ret.qid.path = direntry.path;
	ret.name = direntry.name;

	return ref ret;
}


