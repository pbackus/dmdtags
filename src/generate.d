module generate;

import tag: Tag, Kind;

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
