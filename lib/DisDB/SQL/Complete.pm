#!/usr/bin/env perl
package DisDB::SQL::Complete;

use strict;
use warnings;
our $VERSION = '1.00';
use base 'Exporter';

use DisDB::SQL::Connect qw/:all/;

our %EXPORT_TAGS = (
'all' => [ qw/
    completeGenomeName
    completeSequenceID
    completeTaxonomyName
/ ]
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

sub completeGenomeName {
    my ($query, $dbh) = @_;
    $dbh //= dbConnect('superfamily');
    my $close_dbh = (@_ > 1)?1:0;
    my $genomes = $dbh->selectall_arrayref(
        "SELECT name, genome
        FROM genome 
        WHERE name 
        RLIKE ? 
        AND include = 'y'
        LIMIT 10",
        { Columns=>[1,2] },
        "^<i>$query.*"
    );
    dbDisconnect($dbh) if $close_dbh;
    #Simplify the genome name
    @$genomes = map { ($_->[0]) = $_->[0] =~ /<i>(.*)<\/i>/; {label =>$_->[0],value => $_->[1]};} @$genomes;
    return $genomes;
}

sub completeSequenceID {
    return;
}

sub completeTaxonomyName {
    return;
}

1;
