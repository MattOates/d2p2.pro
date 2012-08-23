#!/usr/bin/env perl
package DisDB::SQL::Figure;

use strict;
use warnings;

our $VERSION = '1.00';
use base 'Exporter';

use DisDB::SQL::Connect qw/dbConnect dbDisconnect/;

our %EXPORT_TAGS = (
'all' => [ qw/
            getPredictorPercentCoverage
/ ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

=item getPredictorPercentCoverage - Retrieve a histogram of the protein percent coverage per protein for a predictor
 params: predictor_id, optional DBI handle
 returns: A 2D array ref of two columns [[percent, frequency],...]
=cut
sub getPredictorPercentCoverage {
    my ($predictor_id, $dbh) = @_;
    $dbh = dbConnect('disorder') unless defined $dbh;
    my $close_dbh = (@_ > 1)?0:1;
    
    my $coverage;
    my $query = $dbh->prepare(
        "SELECT percent, frequency 
         FROM hist_percent_protein_disordered 
         WHERE predictor = ? 
         ORDER BY percent ASC"
    );
    $query->execute($predictor_id);
    $coverage = $query->fetchall_arrayref;

    dbDisconnect($dbh) if $close_dbh;
return $coverage;
}

1;
