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
	// tag is visible only in current file
	bool file;
}
