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
	auto tags = appender!(Tag[]);

	static extern(C++)
	void sinkFn(Tag tag, void* context)
	{
		import std.range: put;

		put(*cast(typeof(tags)*) context, tag);
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

struct Tag
{
	// Separate ptr + length for extern(C++) compatibility
	const(char)* identifierPtr;
	size_t identifierLength;
	const(char)* filenamePtr;
	size_t filenameLength;
	size_t lineNumber;

	this(const(char)[] identifier, const(char)[] filename, size_t lineNumber)
	{
		this.identifierPtr = identifier.ptr;
		this.identifierLength = identifier.length;
		this.filenamePtr = filename.ptr;
		this.filenameLength = filename.length;
		this.lineNumber = lineNumber;
	}

	const(char)[] identifier()
	{
		return identifierPtr[0 .. identifierLength];
	}

	const(char)[] filename()
	{
		return filenamePtr[0 .. filenameLength];
	}

	int opCmp(Tag rhs)
	{
		import std.algorithm: cmp;
		import std.utf: byCodeUnit;

		return cmp(this.identifier.byCodeUnit, rhs.identifier.byCodeUnit);
	}

	string toString()
	{
		import std.format;

		return format("%s\t%s\t%s", identifier, filename, lineNumber);
	}
}

alias TagSink = extern(C++) void function(Tag, void*);

void writeTag(TagSink sink, void* context, Dsymbol sym)
{
	import dmd.root.string: toDString;

	if (!sym.loc.isValid) return;
	const(char)[] filename = sym.loc.filename.toDString;
	if (!filename) return;
	auto tag = Tag(sym.ident.toString, filename, sym.loc.linnum);
	sink(tag, context);
}

void writeTag(TagSink sink, void* context, Module m)
{
	if (!m.srcfile.name) return;
	size_t line = m.md ? m.md.loc.linnum : 1;
	auto tag = Tag(m.ident.toString, m.srcfile.toString, line);
	sink(tag, context);
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

	this(TagSink sink, void* context)
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
