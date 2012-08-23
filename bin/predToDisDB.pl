#!/usr/bin/env perl

use warnings;
use strict;

sub all_disorder_positions {
    my ($sequence) = @_;
    my @ret;
    while ($sequence =~ /D+/g) {
        push @ret, [ $-[0], $+[0] ];
    }
    return @ret;
}

my $file = shift @ARGV;
my ($protein) = split /\./, $file;

open FILE, "<$file";

#Skip the header
while (not <FILE> =~ /MODEL/) {};

my $sequence = '';

while (<FILE>) {
	next if $_ =~ /END/;
	my (undef, $disorder) = split /\s/, $_;
	$sequence .= $disorder;
}

close FILE;

my @hits = all_disorder_positions($sequence);

foreach my $hit (@hits) {
	print $protein."\t".(1+$hit->[0])."\t".(1+$hit->[1])."\tPrDOS\n";
}
