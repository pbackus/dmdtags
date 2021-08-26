module dmdtags.span;

// extern(C++) compatible slice type
struct Span(T)
{
	private T* _ptr;
	private size_t _length;

	this(inout(T)[] slice) inout
	{
		_ptr = &slice[0];
		_length = slice.length;
	}

	inout(T)* ptr() inout { return _ptr; }
	size_t length() const { return _length; }

	inout(T)[] opIndex() inout
	{
		return ptr[0 .. length];
	}

	ref inout(T) opIndex(size_t i) inout
	{
		assert(i < length);
		return ptr[i];
	}

	size_t[2] opSlice(size_t dim)(size_t start, size_t end) const
	{
		return [start, end];
	}

	alias opDollar(size_t dim) = length;

	inout(T)[] opIndex(size_t[2] bounds) inout
	{
		size_t start = bounds[0], end = bounds[1];
		assert(start <= end && end <= length);
		return ptr[start .. end];
	}

	int opCmp(const Span rhs) const
	{
		import std.algorithm.comparison: cmp;

		return this[].cmp(rhs[]);
	}

	// qual(Span!T) -> Span!(qual(T))
	auto headMutable(this This)()
	{
		import std.traits: CopyTypeQualifiers;

		return Span!(CopyTypeQualifiers!(This, T))(this[]);
	}

	void toString(Sink)(ref Sink sink)
	{
		import std.algorithm.mutation: copy;

		copy(this[], sink);
	}
}

inout(Span!T) span(T)(inout(T)[] slice)
{
	return inout(Span!T)(slice);
}

unittest {
	int[] arr = [1, 2, 3];
	auto span = span(arr);

	assert(span.length == arr.length);
	assert(span.ptr == arr.ptr);
	assert(span[0] == 1);
	assert(span[] == arr);
	import std.stdio;
	debug writeln(span[1 .. $]);
	assert(span[1 .. $] == arr[1 .. $]);
}
