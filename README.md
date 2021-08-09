dmdtags
=======

A tag generator for D source code that uses the DMD frontend for accurate
parsing.

Usage
-----

    dmdtags [options] [source_paths]

|Option                    |Effect                                                      |
|--------------------------|------------------------------------------------------------|
|`-R`                      |Search directories recursively (default: current directory).|
|`-f tagfile`, `-o tagfile`|Write tags to `tagfile`; `-` for standard output.           |
