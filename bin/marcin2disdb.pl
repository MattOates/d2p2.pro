#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use FileHandle;
use Getopt::Long;
use File::Path qw(make_path);
use DBI;

#Get the proteins in the study loaded
my %proteins_in_study;
open my $proteins_in_study_fh, '<proteins_in_disorder_study';
while (<$proteins_in_study_fh>) {
	chomp;
	$proteins_in_study{$_} = undef;
}
close $proteins_in_study_fh;

my %proteins_already_encoded;

my %predictors = ( 
					'iupred-l' => {'threshold' => 0.5} ,
					'iupred-s' => {'threshold' => 0.5} ,
					'espritz-x' => {'threshold' => 0.1434} ,
					'espritz-d' => {'threshold' => 0.5072},
					'espritz-n' => {'threshold' => 0.3089}
				   );

my $outdir = '.';

GetOptions(
	'out-dir|o=s' => \$outdir
);

sub run_thresh_encode {
	my ($threshold,$probs) = @_;
	my @run_lengths = ();
	my $delimiter = ',';
	my ($dis,$start,$end) = undef;
	my $pos = 1;

	foreach my $prob (split /$delimiter/, $probs) {
		$dis = $prob >= $threshold;
		if (not $dis and $start) {
			push @run_lengths, [$start,$end];
			$start = undef;
		}
		if ($dis and not $start) {
			$start = $pos;
		}
		$end = $pos;
		$pos++;
	}

	#Check for disorder at the very end
	$probs =~ /$delimiter([0-9]*\.?[0-9]+)$/;
	#print STDERR "Disorder at the end $1, threshold is $threshold\n";
	if ($1 >= $threshold) {
		push @run_lengths, [$start,$end];
	}

	return \@run_lengths;
}

sub up2protein {
	my ($protein, $dbh) = @_;
}

unless (-d "$outdir") {
	make_path($outdir);
}

my $dbh = DBI->connect("dbi:mysql:database=superfamily;host=supfam2.cs.bris.ac.uk",'oates',undef) or die $DBI::errstr;
my $up_to_protein = $dbh->prepare("SELECT protein FROM protein WHERE seqid = ? and genome = 'up';");

foreach my $predictor (keys %predictors) {
	my $fh = FileHandle->new;
	$fh->open(">$outdir/$predictor.disrange");
	$predictors{$predictor}{'range_file'} = $fh;
	$fh = FileHandle->new;
	$fh->open(">$outdir/$predictor.prob");
	$predictors{$predictor}{'prob_file'} = $fh;
}

my $line_number = 1;
while (my $record = <>){
   chomp $record;
   next if $record eq ''; #ignore blank lines
   my ($up_id,$iupred_l,$iupred_s,$espritz_x,$espritz_d,$espritz_n) = split /\t/, $record;
   #print STDERR "$up_id\n";
   $predictors{'iupred-l'}{'rec'} = $iupred_l;
   $predictors{'iupred-s'}{'rec'} = $iupred_s;
   $predictors{'espritz-x'}{'rec'} = $espritz_x;
   $predictors{'espritz-d'}{'rec'} = $espritz_d;
   $predictors{'espritz-n'}{'rec'} = $espritz_n;
	my ($protein) = $dbh->selectrow_array($up_to_protein,undef,$up_id);
	next and warn "$up_id not found in database at line $line_number of input file." unless defined $protein;
   #print STDERR "$protein\n";
   next unless defined $protein;
   next if exists $proteins_already_encoded{$protein};

   if (exists $proteins_in_study{$protein}) {
   		#print STDERR "$protein is gunna be encoded!\n";
   		foreach my $predictor (keys %predictors) {
			next and warn "$predictor missing result for $up_id/$protein at line $line_number of input file." unless $predictors{$predictor}{'rec'};
   			my $ranges = run_thresh_encode($predictors{$predictor}{'threshold'},$predictors{$predictor}{'rec'});
			#print Dumper($ranges);
   			my $probs = join ',', map {"0$_"} split /,/, $predictors{$predictor}{'rec'};
			foreach my $range (@$ranges) {
				$predictors{$predictor}{range_file}->print("$protein\t$range->[0]\t$range->[1]\n");
			}
			$predictors{$predictor}{prob_file}->print("$protein\t[$probs]\n");
		}
		$proteins_already_encoded{$protein} = undef;
   }
   $line_number++;
}

foreach my $predictor (keys %predictors) {
	$predictors{$predictor}{range_file}->close;
	$predictors{$predictor}{prob_file}->close;
}
$up_to_protein->finish;
$dbh->disconnect;
