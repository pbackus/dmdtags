module main;

import std.algorithm.searching: endsWith;
import std.range: only;
import std.path: baseName, stripExtension;

import dmd.globals: Loc;
import dmd.dmodule: Module;
import dmd.tokens: TOK;
import dmd.identifier: Identifier;
import dmd.id: Id;

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

void main(string[] args)
{
	import std.exception: enforce;

	enforce(args.length >= 2, "Must pass a source file as an argument");
	enforce(args[1].endsWith(".d", ".di"), "Source file must end in .d or .di");

	string filename = args[1];
	string modname = filename.baseName.stripExtension;

	initializeDMD();

	auto id = Identifier.idPool(modname);
	auto mod = new Module(filename, id, false, false);
	bool success = mod.read(Loc.initial);
	enforce(success, "Failed to read module");

	Module parsedMod = mod.parse();
}
