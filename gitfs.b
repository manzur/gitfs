implement Myfs;

include "sys.m";
	sys: Sys;
sprint: import sys;

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
debugmsg, error, SHALEN, string2path, sha2string, HEADSPATH, OBJECTSTOREPATH: import utils;

debug: int;
stderr: ref Sys->FD;

srv: ref Styxserver;
nav: ref Navigator;

QRoot, QRootCtl, QRootData, QRootLog, QRootConfig, QRootExclude, QRootObjects, QRootFiles, QStaticMax: con big iota;
INITSIZE: con 17;

QMax := QStaticMax;

Item: adt{
	qid: big;
	parentqid: big;
	dirstat: ref Sys->Dir;
	sha1: string;
	filled: int;
	data: array of byte;
};

Head: adt{
	name, sha1: string;
};

table, shatable: ref Strhash[ref Item];
REPOPATH: string;

cwd := big 0;

Myfs: module
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
	
	if(len args < 2)
		usage();
	
	arg := hd (tl args);

	if(len args == 3 && arg == "-d"){
		debug = 1;
		arg = hd (tl (tl args));
	}

	REPOPATH = makeabsolute(arg);
	utils->init(REPOPATH, debug);

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
	while(heads != nil){
		(ret, dirstat) = sys->stat(string2path((hd heads).sha1));
		if(ret == -1){
			error(sprint("head %s couldn't be accessed\n", string2path((hd heads).sha1)));
			continue;
		}
		q := QMax++;
		dirstat.qid.path = q;
		dirstat.qid.qtype |= Sys->QTDIR;
		dirstat.mode = 8r755 | Sys->DMDIR;
		dirstat.name = (hd heads).name;
		elem := ref Item(q, QRoot, ref dirstat, (hd heads).sha1, 0, nil); 
		table.add(string q, elem);
		shatable.add(elem.sha1, elem);
		heads = tl heads;
	}

	uid := dirstat.uid;
	gid := dirstat.gid;
	atime := dirstat.atime;
	mtime := dirstat.mtime;

	qid := Sys->Qid(QRoot, 0, Sys->QTDIR);
	dirstat = Sys->Dir(".", uid, gid, "", qid, 8r755|Sys->DMDIR, atime, mtime, big 0, 0, 0);
	droot := ref Item(QRoot, QRoot, ref dirstat, nil, 1, nil); 
	table.add(string QRoot, droot);

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
					parent := table.find(string item.parentqid);
					head := parent.sha1;
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
					item1 := table.find(string fid.path);
					if(item1.data != nil){
						srv.reply(styxservers->readbytes(m, item1.data));
						continue mainloop;
					}

					path := item1.sha1;
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
					cwd = big 0;
				item := table.find(string navop.path);
				navop.reply <-= (item.dirstat, "");	

		Walk =>
			debugmsg("in walk\n");
			if(navop.name == ".."){
				item := table.find(string cwd);
				item1 := table.find(string item.parentqid);
				debugmsg(sprint("%bd; want to step up?%d\n", cwd, item1 == nil));
				navop.reply <-= (item1.dirstat, nil);
				cwd = item1.qid;
				continue mainloop;
			}
			
			debugmsg(sprint("parent is %bd\n", cwd));
			for(l := findchildren(cwd); l != nil; l = tl l){
				debugmsg("navigate/walk forloop\n");
				dirstat := (hd l).dirstat;
				if(dirstat == nil)
					dirstat = ref sys->stat(string2path((hd l).sha1)).t1;

				debugmsg(sprint("WALKING %s; %s\n", navop.name, dirstat.name));
				if(dirstat.name == navop.name){
					if(dirstat.qid.qtype & Sys->QTDIR){
						cwd = (hd l).qid;
						debugmsg(sprint("parent is %bd\n", cwd));
					}
					navop.reply <-= (dirstat, nil);
					continue mainloop;
				}
			}
			navop.reply <-= (nil, "not found");

		Readdir =>
			debugmsg("in readdir\n");
			item := table.find(string navop.path);
			if(!item.filled){
				readchildren(item.sha1, navop.path);
				item.filled = 1;
			}
			children := findchildren(navop.path);
			while(children != nil && navop.offset-- > 0){
				children = tl children;
			}
			while(children != nil && navop.count++ > 0){					
				navop.reply <-= ((hd children).dirstat, nil);
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

	debugmsg(sprint("curpath: %s; name: %s\n", curpath, name));
	curpath = resolvepath(curpath, name);
	debugmsg(sprint("curpath: %s; name: %s\n", curpath, name));

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
	debugmsg(sprint("FILETYPE: %s\n", filetype));
	if(filetype == "commit"){

		ibuf := bufio->aopen(filebuf);
		s := ibuf.gets('\n');
		s = s[:len s - 1];

		sha: string;
		(s, sha) = stringmod->splitl(s, " ");
		sha = sha[1:];

		q := big QMax++;
		dirstat := (sys->stat(string2path(sha))).t1;
		item := ref Item(q, parentqid, makedirstat(q, "tree", dirstat), sha, 0, nil);
		table.add(string q, item);
		shatable.add(item.sha1, item);

		parents := "";
		pnum := 1;
		while((s = ibuf.gets('\n')) != ""){
			(recordtype, parent) := stringmod->splitl(s, " ");
			debugmsg(sprint("recordtype: %s==\n", recordtype));
			if(recordtype != "parent")
				break;
			parent = parent[1:];
			parent = parent[:len parent - 1];
			q = QMax++;
			debugmsg(sprint("I ADDED PARENT: %s\n", parent));
			dirstat = (sys->stat(string2path(parent))).t1;
			item = ref Item(q, parentqid, makedirstat(q, "parent" + string pnum++, dirstat), parent, 0, nil);
			table.add(string q, item) ;
			shatable.add(item.sha1, item);
		}

		debugmsg(sprint("parents is %s\n\n", parents));


		msg := s;
		while((s = ibuf.gets('\n')) != ""){
			msg += s;
		}

		q = QMax++;
		item = ref Item(big q, parentqid, makefilestat(q, "commit_msg", dirstat), "", 1, sys->aprint("%s", msg));
		table.add(string q, item);

		#Adding log entry
		q = QMax++;
		item = ref Item(q, parentqid, makefilestat(q, "log", dirstat), "", 1, nil);
		table.add(string q, item);
	}
	else if(filetype == "tree"){
		debugmsg("file tteee\n");
		ibuf := bufio->aopen(filebuf);
		while((s := ibuf.gets('\0'))!= "" ){
			q := QMax++;
			sha := array[SHALEN] of byte;
			ibuf.read(sha, SHALEN);
			shastr := sha2string(sha);
			dirstat := ref (sys->stat(string2path(shastr))).t1; 
			s = s[:len s - 1];
			(mode, name) := stringmod->splitl(s, " ");
			name = name[1:];
			dirstat.name = name; 
			dirstat.qid.path = q;
			item := ref Item(q, parentqid, dirstat, shastr, 0, nil);
			table.add(string q, item);
			shatable.add(item.sha1, item);
		}
	}
}

findchildren(parentqid: big): list of ref Item
{
	l := table.all();
	l1: list of ref Item = nil;
	while(l != nil){
		elem := hd l;
		if(elem.parentqid == parentqid)
			l1 = (hd l) :: l1;
		l = tl l;
	}

	return l1; 
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
