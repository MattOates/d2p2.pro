#!/usr/bin/env bash

perl -na -F'\t' -e 'print "-\n" if $p != $F[0]; $p = $F[0]; print $_;' $1 |
parallel -j 24 --pipe --recstart="-\n" "grep -v '^-' | ./consensus.pl" > $2
