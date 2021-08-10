module dmdtags.appender;

import core.memory: GC;

enum initialCapacity = 16;
enum growFactor = 2;

// Simple extern(C++)-compatible Appender
struct Appender(T)
{
	private static struct Header
	{
		size_t length;
		size_t capacity;
		T[0] data; // for alignment
	}

	private Header* header;

	private static size_t allocSize(size_t capacity)
	{
		import std.experimental.checkedint: checked;

		return (Header.sizeof + T.sizeof.checked * capacity).get;
	}

	private inout(T)[] data() inout
	{
		if (header is null) {
			return null;
		} else {
			return header.data.ptr[0 .. header.length];
		}
	}

	inout(T)[] opIndex() inout
	{
		return data;
	}

	void put(T item)
	{
		import std.experimental.checkedint: checked;

		if (header is null) {
			header = cast(Header*) GC.malloc(allocSize(initialCapacity));
			header.length = 0;
			header.capacity = initialCapacity;
		}

		assert(header.length <= header.capacity);

		if (header.length == header.capacity) {
			T[] oldData = data;
			Header* oldHeader = header;

			immutable size_t newCapacity = (oldHeader.capacity.checked * growFactor).get;
			header = cast(Header*) GC.malloc(allocSize(newCapacity));
			header.length = oldHeader.length;
			header.capacity = newCapacity;

			data[] = oldData[];
		}

		header.length += 1;
		data[$ - 1] = item;
	}
}

unittest {
	import std.range: iota;
	import std.array: array;

	Appender!int app;

	foreach (i; 0 .. 20) {
		app.put(i);
	}

	assert(app[] == iota(20).array);
}
