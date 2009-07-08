implement Gitfs;

include "sys.m";
	sys: Sys;
sprint, print: import sys;

include "draw.m";	

include "styx.m";	
	styx: Styx;
Tmsg, Rmsg: import styx;

include "styxservers.m";
	styxservers: Styxservers;
Navop, Navigator, Fid, Styxserver: import styxservers;

include "daytime.m";
	daytime: Daytime;

include "string.m";
	stringmod: String;

include "log.m";
	log: Log;

include "cat-file.m";
	catfile: Catfile;

include "readdir.m";
	readdir: Readdir;

include "lists.m";
	lists: Lists;

include "tables.m";
	tables: Tables;
Strhash: import tables;	
			 
include "workdir.m";
	gwd: Workdir;

include "bufio.m";
	bufio: Bufio;
Iobuf: import bufio;	

include "utils.m";
	utils: Utils;
debugmsg, error, SHALEN, string2path, sha2string, INDEXPATH, HEADSPATH, OBJECTSTOREPATH: import utils;

include "indexparser.m";
	indexparser: Indexparser;
Gitindex: import indexparser;
	
debug: int;
stderr: ref Sys->FD;

srv: ref Styxserver;
nav: ref Navigator;

QRoot, QRootCtl, QRootData, QRootLog, QRootConfig, QRootExclude, QRootObjects, QRootFiles, QIndex, QIndex1, QIndex2, QIndex3, QStaticMax: con big iota;
INITSIZE: con 17;

QMax := QStaticMax;

#permanent part
Shaobject: adt{
	dirstat: ref Sys->Dir;
	children: list of big;
	sha1: string;
	otype: string;
	data: array of byte;
};

#modifiable part
Direntry: adt{	
	path: big;
	name: string;
	object: ref Shaobject;
	parent: big;

	getdirstat: fn(direntry: self ref Direntry): ref Sys->Dir;
};

Fidqid: adt{
	fid: int;
	path: big;
};

Head: adt{
	name, sha1: string;
};

table: ref Strhash[ref Direntry];
shatable: ref Strhash[ref Shaobject];
REPOPATH: string;

cwd, ppwd: big;
pwds: list of ref Fidqid;

Gitfs: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

 
init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	styx = load Styx Styx->PATH;
	styxservers = load Styxservers Styxservers->PATH;
	readdir = load Readdir Readdir->PATH;
	lists = load Lists Lists->PATH;
	daytime = load Daytime Daytime->PATH;
	tables = load Tables Tables->PATH;
	stringmod = load String String->PATH;
	gwd = load Workdir Workdir->PATH;
	log = load Log Log->PATH;
	catfile = load Catfile Catfile->PATH;
	utils = load Utils Utils->PATH;
	indexparser = load Indexparser Indexparser->PATH; 
	gwd = load Workdir Workdir->PATH;

	if(len args < 2)
		usage();
	
	arg := hd (tl args);

	if(len args == 3 && arg == "-d"){
		debug = 1;
		arg = hd (tl (tl args));
	}

	REPOPATH = makeabsolute(arg);
	utils->init(REPOPATH, debug);
	indexparser->init(REPOPATH :: nil, debug);

	debugmsg(sprint("repopath: %s\n", REPOPATH));

	sys->pctl(Sys->NEWPGRP, nil);
	

	inittable();
 	pwds = ref Fidqid(-1, QRoot) :: pwds;

	styx->init();
	styxservers->init(styx);
	#styxservers->traceset(1);
	navch := chan of ref Navop;
	nav = Navigator.new(navch);
	spawn navigate(navch);
	tmsgchan: chan of ref Tmsg;
	(tmsgchan, srv) = Styxserver.new(sys->fildes(0), nav, big QRoot);
	spawn process(srv, tmsgchan);
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

inittable()
{
	table = Strhash[ref Direntry].new(INITSIZE, nil);
	shatable = Strhash[ref Shaobject].new(INITSIZE, nil);

	direntry: ref Direntry;
	dirstat: Sys->Dir;
	l: list of big;
	ret: int;
	shaobject: ref Shaobject;
	
	heads := readheads(REPOPATH + HEADSPATH, "");
	while(heads != nil){
		head := hd heads;
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
		heads = tl heads;
	}

	shaobject = ref Shaobject(makedirstat(QRoot, dirstat), QIndex :: l, nil, nil, nil);
	direntry = ref Direntry(QRoot, ".", shaobject, big -1);
	table.add(string direntry.path, direntry);

	#Adding index/ and subdirs
	(ret, dirstat) = sys->stat(REPOPATH + INDEXPATH);
	if(ret == -1)
		error(sprint("Index file at %s is not found\n", REPOPATH + INDEXPATH));

	dirstat = *makedirstat(QIndex, dirstat);
	shaobject = ref Shaobject(ref dirstat, QIndex1 :: (QIndex2 :: (QIndex3 :: nil)), nil, "index", nil);
	direntry = ref Direntry(QIndex, "index", shaobject, QRoot);
	table.add(string direntry.path, direntry);
	fillindexdir(direntry, 0);

	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	direntry = ref Direntry(QIndex1, "1", shaobject, QIndex);
	table.add(string direntry.path, direntry);
	fillindexdir(direntry, 1);

	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	direntry = ref Direntry(QIndex2, "2", shaobject, QIndex);
	table.add(string direntry.path, direntry);
	fillindexdir(direntry, 2);
	
	shaobject = ref Shaobject(ref dirstat, nil, nil, "index", nil);
	direntry = ref Direntry(QIndex3, "3", shaobject, QIndex);
	table.add(string direntry.path, direntry);
	fillindexdir(direntry, 3);
}

fillindexdir(parent: ref Direntry, stage: int)
{
	index := indexparser->readindex(stage);
	(ret, dirstat) := sys->stat(REPOPATH + INDEXPATH);
	if(ret == -1){
		error(sprint("Index file at %s is not found\n", REPOPATH + INDEXPATH));
		return;
	}

	ppath := QIndex + big stage;
	direntry: ref Direntry;
	shaobject: ref Shaobject;

	for(i := 0; i < len index.entries; i++){
		sha1 := sha2string(index.entries[i].sha1);
		q := QMax++;
		(dirname, rest) := basename(index.entries[i].name);
		while(dirname != nil){
			child := child(parent, dirname);
			if(child == nil){
				shaobject = ref Shaobject(makedirstat(q, dirstat), nil, nil, nil, nil); 
				child = ref Direntry(q, dirname, shaobject, ppath);
				table.add(string child.path, child);
				parent.object.children = child.path :: parent.object.children;
			}
			parent = child;
			ppath = q;
			q = QMax++;
			(dirname, rest) = basename(rest);
		}
		dirstat = sys->stat(string2path(sha1)).t1;
		shaobject = ref Shaobject(ref dirstat,nil,  sha1, "blob", nil);
		direntry = ref Direntry(q, rest, shaobject, ppath);
		parent.object.children = direntry.path :: parent.object.children;
		table.add(string direntry.path, direntry);
		shatable.add(sha1, shaobject);
	}
}

child(parent: ref Direntry, name: string): ref Direntry
{
	ret: ref Direntry;
	l := parent.object.children;
	while(l != nil){
		ret = table.find(string hd l);
		if(ret != nil && ret.name == name)
			break;
		l = tl l;
	}
	
	return ret;
}

process(srv: ref Styxserver, tmsgchan: chan of ref Tmsg)
{
mainloop:
	while((gm := <-tmsgchan) != nil){
		pick m := gm{
			Stat => 
				debugmsg("in process/stat\n");
				fid := srv.getfid(m.fid); 
				direntry := table.find(string fid.path);
				if(direntry == nil || fid.qtype == Sys->QTDIR){
					srv.stat(m);
					continue mainloop;
				}
				srv.reply(ref Rmsg.Stat(m.tag, *direntry.getdirstat()));

			Create =>
				debugmsg("process/create\n");
				fid := srv.getfid(m.fid);
				sys->print("fid is %d; path is %bd\n", m.fid, fid.path);
				direntry := table.find(string fid.path);
				if(direntry != nil && direntry.object.otype == "index"){
					sys->print("Adding %s ===>%bd\n", m.name, ppwd);
					pwd := "/";
					first := (hd tl pwds).fid;
					second := (hd tl tl pwds).fid;
					third := (hd tl tl tl pwds).fid;
					sys->print("Full path is %d == %d == %d\n", first, second, third);
					sys->print("Full path is %bd == %bd == %bd\n", srv.getfid(first).path, srv.getfid(second).path, srv.getfid(third).path);
					srv.reply(ref Rmsg.Create(m.tag, Sys->Qid(big 11, 0, 0),512));
					continue mainloop;
				}
				srv.default(m);
	
			Read =>
				debugmsg("in process/read\n");
				fid := srv.getfid(m.fid); 
				direntry := table.find(string fid.path);
				buf := array[m.count] of byte;
				ptype: string;
				parent := table.find(string direntry.parent);
				if(parent != nil)
					ptype = parent.object.otype; 

				if(fid.qtype == Sys->QTDIR){
					srv.read(m);
				}
				else if(ptype == "commit" && direntry.name == "log"){
					logch := chan of array of byte;
					head := direntry.object.sha1; 
					debugmsg(sprint("REPOPATH = %s; head is %s\n", REPOPATH, head));

					spawn log->init(logch, REPOPATH :: head :: nil, debug);

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
						if(temp == nil){
							break;
						}
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
					direntry := table.find(string fid.path);
					if(direntry.object.data != nil){
						srv.reply(styxservers->readbytes(m, direntry.object.data));
						continue mainloop;
					}

					path := direntry.object.sha1;
					catch := chan of array of byte;
					
					spawn catfile->init(REPOPATH, 0, path, catch, debug);

					#reading filetype
					<-catch;
					msg := <-catch;
					srv.reply(styxservers->readbytes(m, msg));
				}
			Write =>
				fid := srv.getfid(m.fid);
				cnt := len m.data;
				#some code for processing writing
				srv.reply(ref Rmsg.Write(m.tag, cnt));
			
			Walk => 
				fid := srv.getfid(m.fid);
				pwds = ref Fidqid(m.newfid, fid.path) :: pwds;
				srv.default(m);
			Clunk =>
				debugmsg(sprint("In Clunk %d; hd pwds is %d\n", m.fid, (hd pwds).fid));
				while(pwds != nil && (hd pwds).fid == m.fid){
					pwds = tl pwds;
				}
				srv.default(m);
			* => srv.default(gm);
		}
	}
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
					;#pwds = ref (-1, QRoot) :: nil;
				direntry := table.find(string navop.path);
				navop.reply <-= (direntry.getdirstat(), "");	

			Walk =>
				debugmsg(sprint("in walk: %s\n", navop.name));
				if(navop.name == ".."){
					if(len pwds > 1)
						pwds = tl pwds;
					ppath := table.find(string navop.path).parent;
					direntry := table.find(string ppath);
					navop.reply <-= (direntry.getdirstat(), nil);
					ppwd = cwd;
					cwd = ppath;
					continue mainloop;
				}
			
				debugmsg(sprint("cur path is %bd\n", (hd pwds).path));
				for(l := findchildren(navop.path); l != nil; l = tl l){
					debugmsg("navigate/walk forloop\n");
					direntry := hd l;
					dirstat := direntry.getdirstat();
					#DELME:
					if(dirstat == nil)
					{
						dirstat = ref sys->stat(string2path(direntry.object.sha1)).t1;
					}

					if(dirstat.name == navop.name){
						debugmsg("matching in walking\n");
						if(dirstat.qid.qtype & Sys->QTDIR){
							debugmsg("dir is matched\n");
							ppwd = cwd;
							cwd = navop.path;
							#pwds = (fid.fid, navop.path) :: pwds;
						}
						navop.reply <-= (dirstat, nil);
						continue mainloop;
					}
				}
				navop.reply <-= (nil, "not found");

			Readdir =>
				debugmsg(sprint("in readdir: %bd\n", navop.path));
				item := table.find(string navop.path);
				children := findchildren(navop.path);
				while(children != nil && navop.offset-- > 0){
					children = tl children;
				}
				count := navop.count;
				while(children != nil && count-- > 0){					
					debugmsg("WTFFFF\n");
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

makeabsolute(path: string): string
{
	if(path == "" || path[0] == '/') return path;
	
	name := "";
	curpath := gwd->init();
	for(i := 0; i < len path; i++){
		if(path[i] == '/'){
			curpath = resolvepath(curpath, name);
			name = "";
			continue;
		}
		name[len name] = path[i];
	}

	curpath = resolvepath(curpath, name);

	if(curpath != nil && curpath[len curpath - 1] != '/'){
		curpath += "/";
	}

	return curpath;
}

resolvepath(curpath: string, path: string): string
{

	if(curpath == "/") return curpath + path;

	if(path == ".")
		return curpath;

	if(path == "..")
	{
		oldpath := gwd->init();
		sys->chdir(curpath);
		sys->chdir("..");
		ret := gwd->init();
		sys->chdir(oldpath);
		return ret;
	}

	return curpath + "/" + path;
}

readchildren(sha1: string, parentqid: big)
{

	(filetype, filesize, filebuf) :=  utils->readsha1file(sha1);
	debugmsg(sprint("IN  READCHILDREN sha is %s == filetype == %s\n", sha1, filetype));
	parent := table.find(string parentqid);
	if(filetype == "commit"){
		ibuf := bufio->aopen(filebuf);
		s := ibuf.gets('\n');
		s = s[:len s - 1];

		sha: string;
		(s, sha) = stringmod->splitl(s, " ");
		sha = sha[1:];

		q := QMax++;
		shaobject := shatable.find(sha);
		dirstat := (sys->stat(string2path(sha))).t1;
		if(shaobject == nil){
			shaobject = ref Shaobject(makedirstat(q, dirstat), nil, sha, filetype, nil);
			shatable.add(shaobject.sha1, shaobject);
		}
		direntry := ref Direntry(q, "tree", shaobject, parent.path);
		table.add(string direntry.path, direntry);
		parent.object.children = direntry.path :: parent.object.children;

		parents := "";
		pnum := 1;
		while((s = ibuf.gets('\n')) != ""){
			recordtype: string;
			(recordtype, sha) = stringmod->splitl(s, " ");
			if(recordtype != "parent")
				break;
			sha = sha[1:len sha - 1];
			shaobject = shatable.find(sha);

			q = QMax++;
			name := "parent" + string pnum++;
			dirstat = (sys->stat(string2path(sha))).t1;
			shaobject = shatable.find(sha);
			if(shaobject == nil){
				shaobject = ref Shaobject(makedirstat(q, dirstat), nil, sha, "commit", nil);
				shatable.add(sha, shaobject);
			}
			direntry = ref Direntry(q, name, shaobject, parent.path);

			table.add(string direntry.path, direntry) ;
			parent.object.children = direntry.path :: parent.object.children;
		}

		msg := s;
		while((s = ibuf.gets('\n')) != ""){
			msg += s;
		}

		createlogstat(parent, ref dirstat, msg);
	}
	else if(filetype == "tree"){
		debugmsg("file tteee\n");
		ibuf := bufio->aopen(filebuf);

		while((s := ibuf.gets('\0'))!= ""){
			q := QMax++;
			sha := array[SHALEN] of byte;
			ibuf.read(sha, SHALEN);
			shastr := sha2string(sha);
			shaobject := shatable.find(shastr);
			s = s[:len s - 1];
			(mode, name) := stringmod->splitl(s, " ");
			name = name[1:];
			if(shaobject == nil){
				dirstat := sys->stat(string2path(shastr)).t1; 
				shaobject = ref Shaobject(ref dirstat, nil, shastr, "blob", nil);
				shatable.add(shastr, shaobject);
			}
			shaobject.dirstat.mode = 8r644;
			if(utils->isdir(stringmod->toint(mode, 8).t0)){
				shaobject.dirstat = makedirstat(q, *shaobject.dirstat);
			}
			direntry := ref Direntry(q, name, shaobject, parent.path);
			table.add(string direntry.path, direntry);
			parent.object.children = direntry.path :: parent.object.children;
		}
	}
}

createlogstat(parent: ref Direntry, dirstat: ref Sys->Dir, msg: string)
{
	q := QMax++;
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

convertpath(path: string): string
{
	ret := "";
	for(i := 0; i < len path; i++){
		c := path[i];
		if(c == '/')
			c = '+';
		ret[i] = c;
	}

	return ret;
}

basename(path: string): (string, string)
{
	if(path[0] == '/')
		path = path[1:];

	for(i := 0; i < len path; i++){
		if(path[i] == '/')
			return (path[:i], path[i+1:]);
	}

	return (nil, path);
}

printlist(l: list of ref Fidqid)
{
	print("-----------------------\n");
	while(l != nil){
		print("===> %d ==  %bd", (hd l).fid, (hd l).path);
		l = tl l;
	}
	print("-----------------------\n");
}

Direntry.getdirstat(direntry: self ref Direntry): ref Sys->Dir
{
	ret := *direntry.object.dirstat;
	ret.qid.path = direntry.path;
	ret.name = direntry.name;

	return ref ret;
}
