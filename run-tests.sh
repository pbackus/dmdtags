#!/bin/sh

DMDTAGS=${DMDTAGS:-./dmdtags}

if ! [ -x "$DMDTAGS" ]; then
	echo "Can't run dmdtags binary at $DMDTAGS"
	exit 1
fi

for srcfile in test/*.d; do
	base="${srcfile%.d}"
	./dmdtags -o "${base}.actual" "$srcfile"
	diff -q "${base}.expected" "${base}.actual"
done
