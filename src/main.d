module main;

import std.meta: AliasSeq;

import dmd.frontend: initDMD, parseModule;
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
	import std.array: appender;
	import std.algorithm: sort, each;
	import std.stdio: writeln;

	checkUsage(args);
	string[] paths = args[1 .. $];

	initDMD();
	auto tags = appender!(const(char)[][]);

	static extern(C++)
	void sinkFn(const(char)* ptr, size_t length, void* context)
	{
		import std.range: put;

		put(*cast(typeof(tags)*) context, ptr[0 .. length]);
	}

	scope tagger = new SymbolTagger(&sinkFn, &tags);

	foreach (path; paths) {
		auto parseResult = parseModule(path);
		parseResult.module_.accept(tagger);
	}

	sort(tags[]);
	writeln("!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/");
	tags[].each!writeln;
}

void checkUsage(string[] args)
{
	import std.exception: enforce;
	import std.algorithm.searching: endsWith;

	enforce(args.length >= 2, "Must pass a source file as an argument");
	enforce(args[1].endsWith(".d", ".di"), "Source file must end in .d or .di");
}

alias TagSink = extern(C++) void function(const(char)*, size_t, void*);

void writeTag(TagSink sink, void* context, Dsymbol sym)
{
	import std.format;
	import dmd.root.string: toDString;

	if (!sym.loc.isValid) return;
	const(char)[] filename = sym.loc.filename.toDString;
	if (!filename) return;
	string tag = format("%s\t%s\t%s", sym.ident.toString, filename, sym.loc.linnum);
	sink(tag.ptr, tag.length, context);
}

void writeTag(TagSink sink, void* context, Module m)
{
	import std.format;

	if (!m.srcfile.name) return;
	size_t line = m.md ? m.md.loc.linnum : 1;
	string tag = format("%s\t%s\t%s", m.ident.toString, m.srcfile.toString, line);
	sink(tag.ptr, tag.length, context);
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

extern(C++) class SymbolTagger : SemanticTimeTransitiveVisitor
{
	import dmd.dsymbol: ScopeDsymbol;

	private void* context;
	private TagSink sink;

	extern(D) this(TagSink sink, void* context)
	{
		this.sink = sink;
		this.context = context;
	}

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
			writeTag(sink, context, sym);
			static if (is(Symbol : ScopeDsymbol))
				visitMembers(sym);
		}
	}
}
