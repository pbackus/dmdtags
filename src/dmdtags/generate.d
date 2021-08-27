module dmdtags.generate;

import dmdtags.tag: Kind;
import dmdtags.appender: Appender;
import dmdtags.span;

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

import std.meta: AliasSeq;

void putTag(ref Appender!(Span!(const(char))) sink, Dsymbol sym, bool isPrivate)
{
	import dmd.root.string: toDString;
	import std.range: put;
	import std.format: format;

	if (!sym.loc.isValid) return;
	const(char)[] filename = sym.loc.filename.toDString;
	if (!filename) return;
	const(char)[] tag = format(
		"%s\t%s\t%s;\"\t%s",
		sym.ident.toString, filename, sym.loc.linnum, cast(char) sym.tagKind
	);
	if (isPrivate) {
		tag ~= "\tfile:";
	}
	put(sink, tag.span.headMutable);
}

void putTag(ref Appender!(Span!(const(char))) sink, Module m, bool isPrivate)
{
	import std.range: put;
	import std.format: format;

	if (!m.srcfile.name) return;
	size_t line = m.md ? m.md.loc.linnum : 1;
	const(char)[] tag = format(
		"%s\t%s\t%s;\"\t%s",
		m.ident.toString, m.srcfile.toString, line, cast(char) m.tagKind
	);
	put(sink, tag.span.headMutable);
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
	import dmd.attrib: VisibilityDeclaration;

	private Appender!(Span!(const(char)))* sink;
	private VisibilityDeclaration vd;

	this(ref Appender!(Span!(const(char))) sink)
	{
		this.sink = &sink;
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

	/* Visibility information is not available via Dsymbol.visible prior to
	 * semantic analysis, so we have to keep track of visibility attributes
	 * while walking the parse tree.
	 */
	override void visit(VisibilityDeclaration innerVd)
	{
		auto outerVd = vd;
		vd = innerVd;

		if (vd.decl) {
			foreach (d; *vd.decl) {
				if (d)
					d.accept(this);
			}
		}

		vd = outerVd;
	}

	static foreach (Symbol; TaggableSymbols) {
		override void visit(Symbol sym)
		{
			import dmd.dsymbol: Visibility;

			bool isPrivate = vd && vd.visibility.kind == Visibility.Kind.private_;
			putTag(*sink, sym, isPrivate);

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
