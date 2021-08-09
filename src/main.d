module main;

import std.meta: AliasSeq;

import dmd.frontend: initDMD, parseModule;
import dmd.declaration: AliasDeclaration, VarDeclaration;
import dmd.func: FuncDeclaration;
import dmd.denum: EnumDeclaration, EnumMember;
import dmd.dversion: VersionSymbol;
import dmd.dstruct: StructDeclaration, UnionDeclaration;
import dmd.dclass: ClassDeclaration, InterfaceDeclaration;
import dmd.dtemplate: TemplateDeclaration;
import dmd.nspace: Nspace;
import dmd.dmodule: Module;
import dmd.dsymbol: Dsymbol;
import dmd.visitor: Visitor, SemanticTimeTransitiveVisitor;

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

void printUsage()
{
	import std.stdio: stderr, writeln;

	stderr.writeln("Usage: dmdtags [-R] [path...]");
}

void tryMain(string[] args)
{
	import std.array: appender;
	import std.algorithm: sort, each;
	import std.getopt: getopt;
	import std.stdio: writeln;
	import std.file: isDir, isFile, dirEntries, SpanMode;

	bool recurse;
	auto result = args.getopt(
		"recurse|R", &recurse
	);

	if (result.helpWanted) {
		printUsage();
		return;
	}

	string[] paths;
	if (args.length > 1) {
		paths = args[1 .. $];
	} else if (recurse) {
		paths = ["."];
	} else {
		printUsage();
		return;
	}

	initDMD();
	auto tags = appender!(Tag[]);

	static extern(C++)
	void sinkFn(Tag tag, void* context)
	{
		import std.range: put;

		put(*cast(typeof(tags)*) context, tag);
	}

	scope tagger = new SymbolTagger(&sinkFn, &tags);

	void processSourceFile(string path)
	{
		auto parseResult = parseModule(path);
		parseResult.module_.accept(tagger);
	}

	foreach (path; paths) {
		if (path.isFile) {
			processSourceFile(path);
		} else if (recurse && path.isDir) {
			foreach (entry; dirEntries(path, "*.{d,di}", SpanMode.depth)) {
				if (entry.isFile) {
					processSourceFile(entry.name);
				}
			}
		}
	}

	sort(tags[]);
	writeln("!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/");
	tags[].each!writeln;
}

enum Kind : char
{
	unknown    = ' ', // default
	alias_     = 'a', // aliases
	class_     = 'c', // classes
	enum_      = 'g', // enumeration names
	enumMember = 'e', // enumerators (values inside an enumeration)
	function_  = 'f', // function definitions
	interface_ = 'i', // interfaces
	member     = 'm', // class, struct, and union members
	module_    = 'M', // modules
	namespace  = 'n', // namespaces
	struct_    = 's', // structure names
	template_  = 'T', // templates
	union_     = 'u', // union names
	variable   = 'v', // variable definitions
	version_   = 'V', // version statements
}

struct Tag
{
	// Separate ptr + length for extern(C++) compatibility
	const(char)* identifierPtr;
	size_t identifierLength;
	const(char)* filenamePtr;
	size_t filenameLength;
	size_t lineNumber;
	Kind kind;

	this(const(char)[] identifier, const(char)[] filename, size_t lineNumber, Kind kind)
	{
		this.identifierPtr = identifier.ptr;
		this.identifierLength = identifier.length;
		this.filenamePtr = filename.ptr;
		this.filenameLength = filename.length;
		this.lineNumber = lineNumber;
		this.kind = kind;
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

		return format("%s\t%s\t%s;\"\t%s",
			identifier, filename, lineNumber, cast(char) kind
		);
	}
}

alias TagSink = extern(C++) void function(Tag, void*);

void writeTag(TagSink sink, void* context, Dsymbol sym)
{
	import dmd.root.string: toDString;

	if (!sym.loc.isValid) return;
	const(char)[] filename = sym.loc.filename.toDString;
	if (!filename) return;
	auto tag = Tag(sym.ident.toString, filename, sym.loc.linnum, sym.tagKind);
	sink(tag, context);
}

void writeTag(TagSink sink, void* context, Module m)
{
	if (!m.srcfile.name) return;
	size_t line = m.md ? m.md.loc.linnum : 1;
	auto tag = Tag(m.ident.toString, m.srcfile.toString, line, m.tagKind);
	sink(tag, context);
}

alias TaggableSymbols = AliasSeq!(
	AliasDeclaration,
	VarDeclaration,
	FuncDeclaration,
	EnumMember,
	VersionSymbol,
	StructDeclaration,
	// UnionDeclaration
	ClassDeclaration,
	// InterfaceDeclaration
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

Kind tagKind(Dsymbol sym)
{
	static extern(C++) class SymbolKindVisitor : Visitor
	{
		Kind result;

		alias visit = typeof(super).visit;

		override void visit(AliasDeclaration)
		{
			result = Kind.alias_;
		}

		override void visit(ClassDeclaration)
		{
			result = Kind.class_;
		}

		override void visit(EnumDeclaration)
		{
			result = Kind.enum_;
		}

		override void visit(EnumMember)
		{
			result = Kind.enumMember;
		}

		override void visit(FuncDeclaration)
		{
			result = Kind.function_;
		}

		override void visit(InterfaceDeclaration)
		{
			result = Kind.interface_;
		}

		override void visit(Module)
		{
			result = Kind.module_;
		}

		override void visit(Nspace)
		{
			result = Kind.namespace;
		}

		override void visit(StructDeclaration)
		{
			result = Kind.struct_;
		}

		override void visit(TemplateDeclaration)
		{
			result = Kind.template_;
		}

		override void visit(UnionDeclaration)
		{
			result = Kind.union_;
		}

		override void visit(VarDeclaration vd)
		{
			if (vd.parent && vd.parent.isAggregateDeclaration)
				result = Kind.member;
			else
				result = Kind.variable;
		}

		override void visit(VersionSymbol)
		{
			result = Kind.version_;
		}
	}

	scope v = new SymbolKindVisitor();
	sym.accept(v);
	return v.result;
}
