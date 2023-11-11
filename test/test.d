/++
Test module for dmdtags.

Author: Paul Backus
+/
module test;

int x;

struct S
{
	interface I {}
	union {
		int z;
		double w;
		class C : I {}
		C c;
	}
	int y;
	void method() {}
}

enum E
{
	enumMember
}

void fun()
{
	struct Local {}
}

import std.meta: AliasSeq;

alias ThreeInts = AliasSeq!(int, int, int);
ThreeInts stuff;

template temp(T)
{
	enum foo = T.sizeof;
	enum bar = T.stringof;
}

void eponymous(T)(T t) {}

template overloaded(T)
{
	T overloaded(int) {}
	T overloaded(double) {}
}

version (Foo) int versionedSymbol;

private int privateVar;

private struct PrivateStruct
{
	int privateMember;
}

template eponymousWithExtra()
{
	int eponymousWithExtra;
	int hidden;
}
