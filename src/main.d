module main;

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

	stderr.writeln("Usage: dmdtags [-R] [-f|-o tagfile] [path...]");
}

void tryMain(string[] args)
{
	import generate: SymbolTagger;
	import tag: Tag;

	import dmd.frontend: initDMD, parseModule;

	import std.array: appender;
	import std.algorithm: sort, each;
	import std.getopt: getopt;
	import std.stdio: File, stdout;
	import std.file: isDir, isFile, dirEntries, SpanMode;

	bool recurse;
	string tagfile = "tags";

	auto result = args.getopt(
		"recurse|R", &recurse,
		"f|o", &tagfile,
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

	File output;
	if (tagfile == "-") {
		output = stdout;
	} else {
		output = File(tagfile, "w");
	}

	output.writeln("!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/");
	tags[].each!((tag) { output.writeln(tag); });
}
