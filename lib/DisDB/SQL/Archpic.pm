#!/usr/bin/env perl
package DisDB::SQL::Archpic;

use strict;
use warnings;

our $VERSION = '1.00';
use base 'Exporter';

use DisDB::Util::DBConnect;

our %EXPORT_TAGS = (
'all' => [ qw/
			archpic
/ ],
'arch' => [ qw/
			archpic
/ ]
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

=item archpic - Get an SVG rendering of a protein
 params: protein_id, optional DBI handle
 returns: A single comb string, or a hash of protein id mapped to combs
=cut
sub archpic {
    my ($prot_id,$dbh) = @_;
    $dbh = dbConnect('superfamily') unless defined $dbh;
    my $close_dbh = (@_ > 1)?1:0;
    
    my $comb;
    my $query = $dbh->prepare(
        "SELECT comb 
         FROM comb, comb_index 
         WHERE comb.comb_id = comb_index.id
             AND comb.protein = ?"
    );
        if (ref $prot_id eq "ARRAY") {
                $comb = {};
                foreach my $id (@$prot_id) {
                        $query->execute($id);
                        map {$comb->{$id} = $_} $query->fetchrow_array;
                }
        }
        else {
                $query->execute($prot_id);
                ($comb) = $query->fetchrow_array;
        }

    dbDisconnect($dbh) if $close_dbh;
return $comb;
}


