module main;

import std.meta: AliasSeq;

import dmd.declaration: AliasDeclaration, VarDeclaration;
import dmd.func: FuncDeclaration;
import dmd.denum: EnumDeclaration, EnumMember;
import dmd.dversion: VersionSymbol;
import dmd.dstruct: StructDeclaration;
import dmd.dclass: ClassDeclaration;
import dmd.dtemplate: TemplateDeclaration;
import dmd.nspace: Nspace;
import dmd.dmodule: Module;
import dmd.dsymbol: Dsymbol;
import dmd.visitor: SemanticTimeTransitiveVisitor;

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
	scope v = new DeclarationVisitor();
	parsedMod.accept(v);
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

void writeTag(Dsymbol sym)
{
	import std.stdio: writefln;
	import dmd.root.string: toDString;

	if (!sym.loc.isValid) return;
	const(char)[] filename = sym.loc.filename.toDString;
	if (!filename) return;
	writefln("%s\t%s\t%s", sym.ident.toString, filename, sym.loc.linnum);
}

void writeTag(Module m)
{
	import std.stdio: writefln;

	if (!m.srcfile.name) return;
	size_t line = m.md ? m.md.loc.linnum : 1;
	writefln("%s\t%s\t%s", m.ident.toString, m.srcfile.toString, line);
}

alias TaggableSymbols = AliasSeq!(
	AliasDeclaration,
	VarDeclaration,
	FuncDeclaration,
	EnumMember,
	VersionSymbol,
	StructDeclaration,
	ClassDeclaration,
	EnumDeclaration,
	TemplateDeclaration,
	Nspace,
	Module
);

extern(C++) class DeclarationVisitor : SemanticTimeTransitiveVisitor
{
	import dmd.dsymbol: ScopeDsymbol;

	alias visit = typeof(super).visit;

	void visitMembers(ScopeDsymbol s)
	{
		if (s.members) {
			foreach (m; *s.members) {
				if (m)
					m.accept(this);
			}
		}
	}

	static foreach (Symbol; TaggableSymbols) {
		override void visit(Symbol sym)
		{
			writeTag(sym);
			static if (is(Symbol : ScopeDsymbol))
				visitMembers(sym);
		}
	}
}
