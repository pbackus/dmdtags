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

struct Fields
{
	Kind kind;

	Scope scope_;

	// function parameters
	const(char)[] signature;

	// tag is visible only in current file
	bool file;

	string toString()
	{
		import std.string: chomp;
		import std.conv: to;

		string result;

		result ~= "\t";
		result ~= cast(char) kind;

		if (scope_.kind != Kind.unknown) {
			result ~= "\t";
			result ~= scope_.kind.to!string.chomp("_");
			result ~= ":";
			result ~= scope_.identifier;
		}

		if (signature) {
			result ~= "\tsignature:";
			result ~= signature;
		}

		if (file)
			result ~= "\tfile:";

		return result;
	}
}

struct Scope
{
	Kind kind;
	const(char)[] identifier;
}
