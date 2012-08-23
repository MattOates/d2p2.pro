#!/usr/bin/env perl

use warnings;
use strict;
use DBI;
use FileHandle;
use Getopt::Long;
use Data::Dumper;

sub all_disorder_positions {
    my ($sequence) = @_;
    my @ret;
    while ($sequence =~ /D+/g) {
        push @ret, [ $-[0], $+[0] ];
    }
    return @ret;
}

my $verbose;
my $debug;
my $help;
my $outdir = '.';

#Set command line flags and parameters.
GetOptions(
           "verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "outdir|o=s" => \$outdir,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

$outdir =~ s/\/$//;
foreach my $file (@ARGV) {

    #pid\tstart\tend\tpredictor
    my $disfile = FileHandle->new(">$outdir/$file.disrange");

    #pid\tprobs\tpredictor
    my $probfile = FileHandle->new(">$outdir/$file.prob");

    my $dbh = DBI->connect("dbi:SQLite:$file",undef,undef,
                            {RaiseError => 1, AutoCommit => 1}
                          );

    #prdos (sid integer primary key, sequence text, casp9 text)
    my $sth = $dbh->prepare("SELECT sid, casp9 FROM prdos");
    $sth->execute;

    while (my ($protein, $casp9) = $sth->fetchrow_array()) {
        warn "Protein $protein doesn't have a casp9 string." and next if $casp9 eq '';
        warn "Protein not defined" and last if not defined $protein;
        #Deal with some files incorrectly having literal '\n' rather than a newline character
        $casp9 =~ s/\\n/\n/g;
        my @residues = split /\n/, $casp9;
        my $sequence = '';
        my @probabilities = ();

        #Skip the header
        while ( (scalar @residues) and (shift(@residues) !~ /MODEL/)){}
        warn "Protein $protein in $file has no MODEL section..." and next unless scalar @residues;
        foreach my $residue (@residues) {
            last if $residue =~ /END/;
            my ($amino, $disorder, $prob) = split /\s/, $residue;
            $sequence .= $disorder;
            push @probabilities, $prob;
        }

        my $probs = '[';
        $probs .= join ',', @probabilities;
        $probs .= ']';

        print $probfile $protein."\t".$probs."\t"."PrDOS"."\n";

        my @hits = all_disorder_positions($sequence);

        foreach my $hit (@hits) {
            print $disfile $protein."\t".(1+$hit->[0])."\t".(1+$hit->[1])."\tPrDOS\n";
        }

    }
    $sth->finish;
    $dbh->disconnect;
    $disfile->close;
    $probfile->close;
}
