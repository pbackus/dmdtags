module dmdtags.tag;

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
