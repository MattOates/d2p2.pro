#!/usr/bin/env perl
package DisDB::SQL::Search;

use strict;
use warnings;

our $VERSION = '1.00';
use base 'Exporter';

use DisDB::SQL::Connect qw'dbConnect dbDisconnect';

our %EXPORT_TAGS = (
'all' => [ qw/
			getProteinBySeq
			getProteinBySeqID
            getProteinConsensus
/ ],
'arch' => [ qw/
			getProteinBySeq
			getProteinBySeqID
/ ]
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

=item getProteinBySeq - Retrieve proteins by sequence
 params: 
 returns: 
=cut
sub getProteinBySeq {
    my ($sequence,$dbh) = @_;
    $dbh = dbConnect('superfamily') unless defined $dbh;
    my $close_dbh = (@_ > 1)?1:0;
    
    my $proteins;
    my $query = $dbh->prepare(
        "SELECT protein.protein, protein.genome, protein.seqid 
         FROM protein, genome_sequence, disorder.genome
         WHERE protein.protein = genome_sequence.protein
            AND protein.genome = disorder.genome.genome
            AND genome_sequence.sequence  = ?
         ORDER BY protein.genome"
    );
    if (ref $sequence eq "ARRAY") {
            foreach my $seq (@$sequence) {
                    $query->execute($seq);
                    my $result = $query->fetchall_arrayref();
                    if (scalar @{$result} >= 1) {
                        $proteins //= {};
                        $proteins->{$seq} = $result;
                    }
            }
    }
    else {
            $query->execute($sequence);
            my $result = $query->fetchall_arrayref;
            if (scalar @{$result} >= 1) {
                $proteins = $result;
            }
    }

    dbDisconnect($dbh) if $close_dbh;
return $proteins;
}

=item getProteinBySeqID - Retrieve proteins by sequence ID without genome
 params: 
 returns: 
=cut
sub getProteinBySeqID {
    my ($seqid,$dbh) = @_;
    $dbh = dbConnect('superfamily') unless defined $dbh;
    my $close_dbh = (@_ > 1)?1:0;
    
    my $proteins;
    my $query = $dbh->prepare("
        SELECT DISTINCT(protein.protein), count(protein.genome), genome_sequence.sequence
        FROM protein, genome, genome_sequence
        WHERE protein.genome = genome.genome
        AND protein.protein = genome_sequence.protein
        AND protein.seqid=?
        GROUP BY protein.protein
    ");
    if (ref $seqid eq "ARRAY") {
            foreach my $id (@$seqid) {
                    $query->execute($id);
                    my $result = $query->fetchall_arrayref();
                    if ( scalar @$result >= 1 ) {
                        $proteins //= {};
                        $proteins->{$id} = $result;
                    }
                    else {
                        $proteins->{$id} = undef;
                    }
            }
    }
    else {
            $query->execute($seqid);
            my $result = $query->fetchall_arrayref();
            if ( scalar @$result >= 1 ) {
                $proteins = $result; 
            }
    }

    dbDisconnect($dbh) if $close_dbh;
return $proteins;
}

sub getProteinConsensus {
    my ($protein, $cutoff, $dbh) = @_;
    $dbh = dbConnect('disorder') unless defined $dbh;
    my $close_dbh = (@_ > 1)?1:0;
    
    my $consensus = [];
    my $query = $dbh->prepare("
        SELECT start, end
        FROM dis_consensus_assignment
        WHERE protein = ?
        AND cutoff = ?
        ORDER BY start
    ");
    if (ref $protein eq "ARRAY") {
            foreach my $pid (@$protein) {
                $query->execute($pid, $cutoff);
                my $result = $query->fetchall_arrayref();
                if (scalar @$result >= 1) {
                    $consensus //= {};
                    $consensus->{$pid} = $result;
                }
            }
    }
    else {
            $query->execute($protein, $cutoff);
            my $result = $query->fetchall_arrayref();
            if (scalar @$result >= 1) {
                $consensus = $result;
            }
    }

    dbDisconnect($dbh) if $close_dbh;
return $consensus;
}

1;
