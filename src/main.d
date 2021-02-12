module main;

import dmd.dmodule: Module;

int main(string[] args)
{
	import std.stdio: stderr;

	try tryMain(args);
	catch (Exception e) {
		stderr.writeln("dmdtags: ", e.message);
		return 1;
	}
	return 0;
}

void tryMain(string[] args)
{
	checkUsage(args);
	string path = args[1];
	initializeDMD();
	Module parsedMod = parseModule(path);
}

void checkUsage(string[] args)
{
	import std.exception: enforce;
	import std.algorithm.searching: endsWith;

	enforce(args.length >= 2, "Must pass a source file as an argument");
	enforce(args[1].endsWith(".d", ".di"), "Source file must end in .d or .di");
}

void initializeDMD()
{
	import dmd.mtype: Type;
	import dmd.id: Id;
	import dmd.dmodule: Module;
	//import dmd.target: target;
	//import dmd.expression: Expression;
	//import dmd.objc: Objc;
	//import dmd.filecache: FileCache;
	//import dmd.globals: global;

	Type._init();
	Id.initialize();
	Module._init();
	// Since we're just parsing, these shouldn't be necessary...
	//target._init(global.params);
	//Expression._init();
	//Objc._init();
	//FileCache._init();
}

Module parseModule(string path)
{
	import std.path: baseName, stripExtension;
	import std.exception: enforce;

	import dmd.identifier: Identifier;
	import dmd.globals: Loc;

	string modname = path.baseName.stripExtension;
	Identifier id = Identifier.idPool(modname);
	auto mod = new Module(path, id, false, false);
	bool success = mod.read(Loc.initial);
	enforce(success, "Failed to read module");
	return mod.parse();
}
