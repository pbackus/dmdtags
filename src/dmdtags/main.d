module dmdtags.main;

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

void tryMain(string[] args)
{
	import dmdtags.generate: SymbolTagger;

	import dmd.frontend: initDMD, parseModule;
	import dmd.errors: DiagnosticHandler;
	import dmd.globals: global;

	import std.algorithm: sort, uniq, each;
	import std.array: Appender;
	import std.getopt: getopt;
	import std.stdio: File, stdout;
	import std.file: exists, isDir, isFile, dirEntries, SpanMode;

	bool recurse;
	string tagfile = "tags";
	bool append;

	auto result = args.getopt(
		"recurse|R", &recurse,
		"f|o", &tagfile,
		"append|a", &append,
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

	// Ignore all parsing errors and keep going
	DiagnosticHandler ignoreErrors = (ref _1, _2, _3, _4, _5, _6, _7) => true;
	initDMD(ignoreErrors);
	static if (__traits(hasMember, global.params, "errorLimit"))
		// Up to DMD 2.105.3
		global.params.errorLimit = 0;
	else
		// Since DMD 2.106.0
		global.params.v.errorLimit = 0;

	//Appender!(Span!(const(char))) tags;
	Appender!(const(char)[][]) tags;
	scope tagger = new SymbolTagger(tags);

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

	if (append && tagfile.exists) {
		import std.algorithm: filter, startsWith, map, copy;

		File(tagfile, "r")
			.byLineCopy
			.filter!(line => !line.startsWith("!_TAG_"))
			.copy(tags);
	}

	sort(tags[]);

	File output;
	if (tagfile == "-") {
		output = stdout;
	} else {
		output = File(tagfile, "w");
	}

	output.writeln("!_TAG_FILE_SORTED\t1\t/0=unsorted, 1=sorted, 2=foldcase/");
	output.writeln("!_TAG_FILE_ENCODING\tutf-8\t//");

	tags[].uniq.each!(tag => output.writeln(tag));
}

void printUsage()
{
	import std.stdio: stderr, writeln;

	stderr.writeln("Usage: dmdtags [-R] [-a] [-f|-o tagfile] [path...]");
}
