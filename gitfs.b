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

Item: adt{
	qid: big;
	children: list of big;
	dirstat: ref Sys->Dir;
	sha1: string;
	data: array of byte;
};

Head: adt{
	name, sha1: string;
};

table, shatable: ref Strhash[ref Item];
REPOPATH: string;

pwds: list of big;

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
	table = Strhash[ref Item].new(INITSIZE, nil);
	shatable = Strhash[ref Item].new(INITSIZE, nil);

	dirstat: Sys->Dir;
	ret: int;
	
	heads := readheads(REPOPATH + HEADSPATH, "");
	l: list of big;
	while(heads != nil){
		head := hd heads;
		(ret, dirstat) = sys->stat(string2path(head.sha1));
		if(ret == -1){
			error(sprint("head %s couldn't be accessed\n", string2path(head.sha1)));
			continue;
		}
		q := QMax++;
		l = q :: l;
		item := ref Item(q, nil, makedirstat(q, head.name, dirstat), head.sha1, nil); 
		table.add(string q, item);
		shatable.add(item.sha1, item);
		heads = tl heads;
	}

	d := ref Item(QRoot, nil, makedirstat(QRoot, ".", dirstat), nil, nil); 
	table.add(string QRoot, d);

	while(l != nil){
		d.children = (hd l):: d.children;
		l = tl l;
	}
	d.children = QIndex :: d.children; 

	#Adding index/ and subdirs
	d = ref Item(QIndex, nil, makedirstat(QIndex, "index", dirstat), nil, nil);
	table.add(string QIndex, d);
	d.children = QIndex1 :: (QIndex2 :: (QIndex3 :: d.children));
	fillindexdir(d, 0);

	d = ref Item(QIndex1, nil, makedirstat(QIndex1, "1", dirstat), nil, nil);
	table.add(string QIndex1, d);
	fillindexdir(d, 1);

	d = ref Item(QIndex2, nil, makedirstat(QIndex2, "2", dirstat), nil, nil);
	table.add(string QIndex2, d);
	fillindexdir(d, 2);
	
	d = ref Item(QIndex3, nil, makedirstat(QIndex3, "3", dirstat), nil, nil);
	table.add(string QIndex3, d);
	fillindexdir(d, 3);
}

fillindexdir(parent: ref Item, stage: int)
{
	index := indexparser->readindex(stage);
	dirstat := sys->stat(REPOPATH + INDEXPATH).t1;
	for(i := 0; i < len index.entries; i++){
		sha1 := sha2string(index.entries[i].sha1);
		item := shatable.find(sha1);
		if(item == nil){
			q := QMax++;
			(dirname, rest) := basename(index.entries[i].name);
			while(dirname != nil){
				item1 := child(parent, dirname);
				if(item1 == nil){
					item1 = ref Item(q, nil, makedirstat(q, dirname, dirstat), nil, nil);
					table.add(string item1.qid, item1);
					parent.children = q :: parent.children;
					parent = item1;
					q = QMax++;
				}
				else
					parent = item1;

				(dirname, rest) = basename(rest);
			}
			dirstat = sys->stat(string2path(sha1)).t1;
			item = ref Item(q, nil, makefilestat(q, rest, dirstat), sha1, nil);
			parent.children = item.qid :: parent.children;
			table.add(string q, item);
			shatable.add(sha1, item);
		}
		else{
			parent.children = item.qid :: parent.children;
		}
	}
}

child(parent: ref Item, name: string): ref Item
{
	l := parent.children;
	item: ref Item;
	while(l != nil){
		item = table.find(string hd l);
		if(item != nil && item.dirstat.name == name)
			break;
		l = tl l;
	}
	
	return item;
}

process(srv: ref Styxserver, tmsgchan: chan of ref Tmsg)
{
mainloop:
	while((gm := <-tmsgchan) != nil){
		pick m := gm{
			Stat => 
				debugmsg("in process/stat\n");
				fid := srv.getfid(m.fid); 
				item := table.find(string fid.path);
				if(item == nil || fid.qtype == Sys->QTDIR){
					srv.stat(m);
					continue mainloop;
				}
				srv.reply(ref Rmsg.Stat(m.tag, *item.dirstat));

			Read =>
				debugmsg("in process/read\n");
				fid := srv.getfid(m.fid); 
				item := table.find(string fid.path);
				buf := array[m.count] of byte;

				if(fid.qtype == Sys->QTDIR){
					srv.read(m);
				}
				else if(item.dirstat.name == "log"){
					logch := chan of array of byte;
					head := item.sha1; 
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
					item := table.find(string fid.path);
					if(item.data != nil){
						srv.reply(styxservers->readbytes(m, item.data));
						continue mainloop;
					}

					path := item.sha1;
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
					pwds = big QRoot :: nil;
				item := table.find(string navop.path);
				navop.reply <-= (item.dirstat, "");	

			Walk =>
				debugmsg(sprint("in walk: %s\n", navop.name));
				(name1, name2) := basename(navop.name);
				debugmsg(sprint("name is %s == %s\n", name1, name2));
				if(navop.name == ".."){
					pwds = tl pwds;
					item := table.find(string hd pwds);
					navop.reply <-= (item.dirstat, nil);
					continue mainloop;
				}
			
				for(l := findchildren(hd pwds); l != nil; l = tl l){
					debugmsg("navigate/walk forloop\n");
					item := hd l;
					dirstat := item.dirstat;
					if(dirstat == nil)
						dirstat = ref sys->stat(string2path(item.sha1)).t1;

					if(dirstat.name == navop.name){
						debugmsg("matching in walking\n");
						if(dirstat.qid.qtype & Sys->QTDIR){
							debugmsg("dir is matched\n");
							pwds = item.qid :: pwds;
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
					navop.reply <-= ((hd children).dirstat, nil);
					debugmsg("WTFFFF\n");
					children = tl children;
				}
				debugmsg("aADASD\n");
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
	parentitem := table.find(string parentqid);
	if(filetype == "commit"){
		ibuf := bufio->aopen(filebuf);
		s := ibuf.gets('\n');
		s = s[:len s - 1];

		sha: string;
		(s, sha) = stringmod->splitl(s, " ");
		sha = sha[1:];

		q := QMax++;
		item := shatable.find(sha);
		dirstat := (sys->stat(string2path(sha))).t1;
		if(item == nil){
			item = ref Item(q, nil, makedirstat(q, "tree", dirstat), sha, nil);
			table.add(string q, item);
			shatable.add(item.sha1, item);
		}
		
		parentitem.children = item.qid :: parentitem.children;

		parents := "";
		pnum := 1;
		while((s = ibuf.gets('\n')) != ""){
			recordtype: string;
			(recordtype, sha) = stringmod->splitl(s, " ");
			if(recordtype != "parent")
				break;
			sha = sha[1:len sha - 1];
			item = shatable.find(sha);
			#FIXME: Code for reusing commits should be added(if that commit has a tag).
			q = QMax++;
			dirstat = (sys->stat(string2path(sha))).t1;
			item = ref Item(q, nil, makedirstat(q, "parent" + string pnum++, dirstat), sha, nil);
			table.add(string q, item) ;
			shatable.add(item.sha1, item);
			parentitem.children = item.qid :: parentitem.children;
		}

		msg := s;
		while((s = ibuf.gets('\n')) != ""){
			msg += s;
		}

		createlogstat(parentitem, ref dirstat, msg);
	}
	else if(filetype == "tree"){
		debugmsg("file tteee\n");
		ibuf := bufio->aopen(filebuf);

		while((s := ibuf.gets('\0'))!= ""){
			debugmsg("ASDASDASD\n");
			q := QMax++;
			sha := array[SHALEN] of byte;
			ibuf.read(sha, SHALEN);
			shastr := sha2string(sha);
			item := shatable.find(shastr);
			if(item == nil){
				dirstat := sys->stat(string2path(shastr)).t1; 
				s = s[:len s - 1];
				(mode, name) := stringmod->splitl(s, " ");
				name = name[1:];
				dirstat.name = name; 
				debugmsg("ININININIF\n");
				dirstat.qid.path = q;
				item = ref Item(q, nil, ref dirstat, shastr, nil);
				table.add(string q, item);
				shatable.add(item.sha1, item);
				debugmsg("YYYYY\n");
			}
			parentitem.children = item.qid :: parentitem.children;
		}
	}
}

createlogstat(parentitem: ref Item, dirstat: ref Sys->Dir, msg: string)
{
	q := QMax++;
	item := ref Item(q, nil, makefilestat(q, "commit_msg", *dirstat), "", sys->aprint("%s", msg));
	table.add(string q, item);
	parentitem.children = item.qid :: parentitem.children;

	#Adding log entry
	q = QMax++;
	item = ref Item(q, nil, makefilestat(q, "log", *dirstat), parentitem.sha1, nil);
	table.add(string q, item);
	parentitem.children = item.qid :: parentitem.children;
}

findchildren(parentqid: big): list of ref Item
{
	item := table.find(string parentqid);
	if(item.children == nil && parentqid < QIndex && parentqid > QIndex3){
		debugmsg(sprint("not filled %bd\n", parentqid));
		readchildren(item.sha1, parentqid);
	}

	if(item == nil)	
		return nil;

	children: list of ref Item;
	l := item.children;
	while(l != nil){
		item1 := table.find(string hd l);
		if(item1 != nil){
			children = item1 :: children; 
		}

		l = tl l;
	}
	debugmsg(sprint("returning from findchildren %d; pwd is %bd\n", len children, hd pwds));
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

makedirstat(q: big, name: string, src: Sys->Dir): ref Sys->Dir
{
	dirstat := ref src;
	dirstat.qid.path = q;
	dirstat.name = name;
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

printlist(l: list of ref Item)
{
	print("-----------------------\n");
	while(l != nil){
		print("%s ", (hd l).dirstat.name);
		l = tl l;
	}
	print("-----------------------\n");
}
