#!/usr/bin/env perl

use warnings;
use strict;
use FileHandle;
use Getopt::Long;
use Data::Dumper;

sub probs_to_ranges {
	my @probs = @_;
	my @ranges = ();
	my $index = 1;
	my $start = undef;
	my $end = undef;
	my $prob = undef;
	foreach $prob (@probs) {
		if ($prob >= 0.5) {
			$start = $index unless defined $start;
		} else {
			$end = $index-1;
			push @ranges, [$start, $end] if defined $start;
			$start = undef;
		}
		$index++;
	}
	#Deal with the edge case where there is a disordered domain to the end of the sequence
	if ($probs[-1] >= 0.5) {
			$end = $index-1;
			push @ranges, [$start, $end] if defined $start;
	}
	return @ranges;
}

sub write_protein_records {
	my ($files, $protein, $ranges, $anchor_probs, $iupred_probs) = @_;
	my ($iupred_disfile,$anchor_disfile,$iupred_probfile,$anchor_probfile) = @$files;
	foreach my $range (@$ranges) {
		$anchor_disfile->print("$protein\t$range->[0]\t$range->[1]\tANCHOR\n");
	}
	foreach my $range (probs_to_ranges(@$iupred_probs)) {
		$iupred_disfile->print("$protein\t$range->[0]\t$range->[1]\tIUPred\n");
	}
	my $probs = join ',', @$anchor_probs;
	$anchor_probfile->print("$protein\t$probs\tANCHOR\n");
	$probs = join ',', @$iupred_probs;
	$iupred_probfile->print("$protein\t$probs\tIUPred\n");
}



my $verbose;
my $debug;
my $help;
my $outfile;

#Set command line flags and parameters.
GetOptions(
           "verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "outfile|o=s" => \$outfile,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

die "No outfile prefix specified." unless $outfile;

my $iupred_disfile = FileHandle->new(">${outfile}_iupred.disrange");
my $anchor_disfile = FileHandle->new(">${outfile}_anchor.disrange");
my $iupred_probfile = FileHandle->new(">${outfile}_iupred.prob");
my $anchor_probfile = FileHandle->new(">${outfile}_anchor.prob");
my $files = [$iupred_disfile,$anchor_disfile,$iupred_probfile,$anchor_probfile];

my $protein;
my @iupred_probs = ();
my @anchor_probs = ();
my @anchor_ranges = ();

#   Columns:
#   1 - Amino acid number
#   2 - One letter code
#   3 - ANCHOR probability value
#   4 - ANCHOR output
#   5 - IUPred probability value
#   6 - ANCHOR score 
#   7 - S 
#   8 - Eint 
#   9 - Egain

my $line = <STDIN>;
chomp $line;
my $nextline;
while ($line) {
	#Look a single line ahead to work out when we are at the end of a record
	$nextline = <STDIN>;
	chomp $nextline if $nextline;
	
	#If we are starting a new record
	if ($line =~ /^###/) {
		#Record the protein ID
		(undef,$protein) = split /###/, $line;
		#Then skip to the Predicted binding regions table
		while ($line !~ /^# Predicted binding regions/) { $line = <STDIN>; }
		$line = <STDIN>;
		#If we have some predicted binding sites add them to the list
		if ($line !~ /none/i) {
			while ($line = <STDIN>) {
				last if $line =~ /^#\s+$/;
				$line =~ s/^#\s+//;
				my (undef, $start, $end) = split /\s+/, $line;
				push @anchor_ranges, [$start,$end];
			}
		} else { warn "No binding sites found for $protein"; }
	}

	#If a line doesn't start with a hash assume it's model output
	if ($line !~ /^#/) {
		#Only bother to store the probability columns for this protein
		my (undef,undef,$anchor_prob,undef,$iupred_prob) = split /\t/, $line;
		#Push these onto the list
		$anchor_prob =~ s/\s//g;
		$anchor_prob =~ s/0+$//g;
		$iupred_prob =~ s/\s//g;
		$iupred_prob =~ s/0+$//g;
		push @anchor_probs, $anchor_prob;
		push @iupred_probs, $iupred_prob;
	}

	#If this was the last line of this record then write out the current data
	if ( $line !~ /^###/ and (not defined $nextline or $nextline =~ /^###/) ) {
		write_protein_records($files,$protein,\@anchor_ranges,\@anchor_probs,\@iupred_probs);
		@anchor_ranges = ();
		@anchor_probs = ();
		@iupred_probs = ();
	}
	$line = $nextline;
}

