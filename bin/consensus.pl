#!/usr/bin/env perl

use warnings;
use strict;
use DBI;

my %proteins;
my $currentpos=1;
my $num_predictors = 2;

my ($db_host,$db_user,$db_password) = qw/supfam2 oates/;

sub consensus {
	my ($num_predictors, $length, $ranges, $protein) = @_;
	#Consensus row vector for this protein
	my @consensus = ((0)x$length);
	#List of contigous regions of disorder that agree
	my @consranges;
	
	#Count how many predictors assigned this amino acid position as disordered
	foreach my $range (@$ranges) {
		#map the amino positions into 0 offset array indices
		my ($s, $e) = map {--$_} @$range;
		#Slice the array on those indices and add 1 to the values there
		@consensus[$s..$e] = map {++$_} @consensus[$s..$e];
	}
	
	#Remove all predictions that conflict with SF domain predictions
	my @structured;
	my $dbh= DBI->connect("dbi:mysql:database=superfamily;host=$db_host",$db_user,$db_password) or die $DBI::errstr;
	my $structured_hits = $dbh->selectall_arrayref("SELECT region FROM ass WHERE evalue <= 0.0001 AND protein = ? ORDER BY evalue ASC",undef,$protein);
	$dbh->disconnect;
	push @structured, map {[split /-/, $_]} map {split /,/,$_->[0]} @$structured_hits;
	foreach my $struct (@structured) {
		#map the amino positions into 0 offset array indices
		my ($s, $e) = map {--$_} @$struct;
		#Slice the array on those indices and set to 0
		@consensus[$s..$e] = ((0)x(1+$e-$s));
	}
	
	my $start; #Current range start
	my $range; #Current range length
	my $new = 1; #Starting on a new assignment

	#Foreach amino acid position see if we are above 50% consensus and store that contiguous range
	for (my $i = 0; $i <= $#consensus; $i++ ) {
		#Are we above consensus threshold
		if ( ($consensus[$i] / $num_predictors) > 0.5) {
			#If this is a new assignment region set the start position
			if ($new) {
				$start = $i+1;
				$new = 0;
			}
			#Increase the range of this segment of disorder by one
			$range++;
		}
		#If we are below consensus threshold store the current region and reset
		else {
			unless ($new) {
				push @consranges, [$start, $start+($range-1)];
				$new = 1;
				$range = 0;
			}
		}
	}
	return \@consranges;
}

while (<>) {
	my ($protein, $start, $end) = split /\t/, $_;
	push @{$proteins{$protein}}, [$start, $end];
}

while (my ($protein, $ranges) = each %proteins) {
	my @consranges;
	my $length = 0;
	foreach my $r (@$ranges) {$length = $r->[1] if $r->[0] > $length;}
	@consranges = @{consensus(2,$length,$ranges,$protein)};
	foreach my $range (@consranges) {
		my ($s,$e) = @$range;
		print "$protein\t$s\t$e\tDfam\n";
	}
}

