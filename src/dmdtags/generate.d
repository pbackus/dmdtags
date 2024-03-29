module dmdtags.generate;

import dmdtags.tag;

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

import std.array: Appender;
import std.meta: AliasSeq;

alias TaggableSymbols = AliasSeq!(
	AliasDeclaration,
	VarDeclaration,
	FuncDeclaration,
	EnumMember,
	VersionSymbol,
	TaggableParentSymbols,
	Nspace,
	Module
);

// Members of these symbols are tagged with
// their parent in the "scope" field.
alias TaggableParentSymbols = AliasSeq!(
	StructDeclaration,
	UnionDeclaration,
	ClassDeclaration,
	InterfaceDeclaration,
	EnumDeclaration,
	TemplateDeclaration,
);

class SymbolTagger : SemanticTimeTransitiveVisitor
{
	import dmd.dsymbol: ScopeDsymbol, foreachDsymbol;
	import dmd.attrib: VisibilityDeclaration;

	private Appender!(const(char)[][])* sink;
	private VisibilityDeclaration vd;
	private ScopeDsymbol parentSym;

	this(ref Appender!(const(char)[][]) sink)
	{
		this.sink = &sink;
	}

	alias visit = typeof(super).visit;

	final void visitMembers(ScopeDsymbol s)
	{
		s.members.foreachDsymbol((m) { if (m) m.accept(this); });
	}

	/* Visibility information is not available via Dsymbol.visible prior to
	 * semantic analysis, so we have to keep track of visibility attributes
	 * while walking the parse tree.
	 */
	extern(C++) override void visit(VisibilityDeclaration innerVd)
	{
		auto outerVd = vd;
		scope(exit) vd = outerVd;

		vd = innerVd;
		vd.decl.foreachDsymbol((d) { if (d) d.accept(this); });
	}

	static foreach (Symbol; TaggableSymbols) {
		extern(C++) override void visit(Symbol sym)
		{
			import dmd.dsymbol: Visibility;
			import std.meta: IndexOf = staticIndexOf;

			Fields fields;
			fields.kind = sym.toKind;
			static if (is(Symbol : ClassDeclaration))
				fields.inherits = sym.baseClassesToString;
			if (parentSym)
				fields.scope_ = Scope(parentSym.toKind, parentSym.ident.toString);
			static if (is(Symbol == FuncDeclaration) || is(Symbol == TemplateDeclaration))
				fields.signature = sym.paramsToString;
			fields.file = vd && vd.visibility.kind == Visibility.Kind.private_;

			putTag(*sink, sym, fields);

			static if (IndexOf!(Symbol, TaggableParentSymbols) >= 0) {
				auto outerParentSym = parentSym;
				scope(exit) parentSym = outerParentSym;
				if (sym.ident)
					parentSym = sym;
			}

			static if (is(Symbol : ScopeDsymbol))
				visitMembers(sym);
		}
	}
}

Kind toKind(Dsymbol sym)
{
	static class SymbolKindVisitor : Visitor
	{
		Kind result;

		alias visit = typeof(super).visit;

		extern(C++):

		override void visit(AliasDeclaration) { result = Kind.alias_; }
		override void visit(ClassDeclaration) { result = Kind.class_; }
		override void visit(EnumDeclaration) { result = Kind.enum_; }
		override void visit(EnumMember) { result = Kind.enumMember; }
		override void visit(FuncDeclaration) { result = Kind.function_; }
		override void visit(InterfaceDeclaration) { result = Kind.interface_; }
		override void visit(Module) { result = Kind.module_; }
		override void visit(Nspace) { result = Kind.namespace; }
		override void visit(StructDeclaration) { result = Kind.struct_; }
		override void visit(TemplateDeclaration) { result = Kind.template_; }
		override void visit(UnionDeclaration) { result = Kind.union_; }

		override void visit(VarDeclaration vd)
		{
			if (vd.parent && vd.parent.isAggregateDeclaration)
				result = Kind.member;
			else
				result = Kind.variable;
		}

		override void visit(VersionSymbol) { result = Kind.version_; }
	}

	scope v = new SymbolKindVisitor();
	sym.accept(v);
	return v.result;
}

const(char)[] paramsToString(FuncDeclaration fd)
{
	import dmd.hdrgen: parametersTypeToChars;
	import std.string: fromStringz;

	if (fd.type) {
		if (auto tf = fd.type.isTypeFunction) {
			return tf.parameterList.parametersTypeToChars.fromStringz;
		}
	}
	return null;
}

const(char)[] paramsToString(TemplateDeclaration td)
{
	import dmd.hdrgen: toCBuffer, HdrGenState;
	import dmd.common.outbuffer: OutBuffer;

	OutBuffer buf;
	HdrGenState hgs;

	buf.writestring("(");

	if (td.parameters) {
		foreach (i, param; *td.parameters) {
			if (i > 0)
				buf.writestring(", ");
			static if (__traits(compiles, param.toCBuffer(&buf, &hgs)))
				// Up to DMD 2.105.3
				param.toCBuffer(&buf, &hgs);
			else
				// Since DMD 2.106.0
				param.toCBuffer(buf, hgs);
		}
	}

	buf.writestring(")");

	return buf.extractSlice;
}

const(char)[] baseClassesToString(ClassDeclaration cd)
{
	import dmd.hdrgen: toCBuffer, HdrGenState;
	import dmd.common.outbuffer: OutBuffer;

	OutBuffer buf;
	HdrGenState hgs;

	if (cd.baseclasses) {
		foreach (i, base; *cd.baseclasses) {
			if (i > 0)
				buf.writestring(",");
			static if (__traits(compiles, base.type.toCBuffer(&buf, null, &hgs)))
				// Up to DMD 2.105.3
				base.type.toCBuffer(&buf, null, &hgs);
			else
				// Since DMD 2.106.0
				base.type.toCBuffer(buf, null, hgs);
		}
	}

	return buf.extractSlice;
}

void putTag(ref Appender!(const(char)[][]) sink, Dsymbol sym, Fields fields)
{
	import dmd.root.string: toDString;
	import std.range: put;
	import std.format: format;

	if (!sym.loc.isValid) return;
	if (!sym.ident) return;

	const(char)[] filename = sym.loc.filename.toDString;
	if (!filename) return;

	const(char)[] tag = format(
		"%s\t%s\t%s;\"%s",
		sym.ident.toString, filename, sym.loc.linnum, fields
	);

	put(sink, tag);
}

void putTag(ref Appender!(const(char)[][]) sink, Module m, Fields fields)
{
	import std.range: put;
	import std.format: format;

	if (!m.srcfile.name) return;

	size_t line = m.md ? m.md.loc.linnum : 1;
	const(char)[] tag = format(
		"%s\t%s\t%s;\"%s",
		m.ident.toString, m.srcfile.toString, line, fields
	);

	put(sink, tag);
}
