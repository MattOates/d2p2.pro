#!/usr/bin/env perl
package DisDB::SQL::Predictor;

use strict;
use warnings;

our $VERSION = '1.00';
use base 'Exporter';

use DisDB::SQL::Connect qw'dbConnect dbDisconnect';

our %EXPORT_TAGS = (
'all' => [ qw/
			getPredictors
			getPredictorPeople
            getPeople
/ ],
'predictor' => [ qw/
			getPredictor
/ ],
'people' => [ qw/
			getPredictorPeople
            getPeople
/ ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

=item getPredictors - Retrieve predictor information by type.
 params: type (disorder, structure, binding), dbh both are optional
 returns: An arrayref of data ordered for display.
=cut
sub getPredictors {
    my ($type, $dbh) = @_;

    my $close_dbh = (defined $dbh)?0:1;
    $dbh = dbConnect('disorder') unless defined $dbh;
    my $query;
    my $predictors;

    if (defined $type) {
        $query = $dbh->prepare('SELECT * FROM predictor WHERE type = ? ORDER BY display_order');
        $query->execute($type);
        $predictors = $query->fetchall_arrayref({});
    } else {
        $query = $dbh->prepare('SELECT * FROM predictor ORDER BY display_order');
        $query->execute();
        $predictors = $query->fetchall_arrayref({});
 
    }

    if (scalar @$predictors < 1) {
        $predictors = undef;
    }

    dbDisconnect($dbh) if $close_dbh;
    return $predictors;
}

=item getPredictorPeople - Get all the people related to each predictor.
 params: type (disorder, structure, binding), dbh both are optional
 returns: An arrayref of data ordered for display.
=cut
sub getPredictorPeople {
    my ($type, $dbh) = @_;

    my $close_dbh = (defined $dbh)?0:1;
    $dbh = dbConnect('disorder') unless defined $dbh;

    my $people;
    my $query;

    if (defined $type) {
         $query = $dbh->prepare(
           "SELECT predictor_people.predictor, is_author, made_predictions, title, first_name, second_name, email, affiliation, website
            FROM predictor, predictor_people, people
            WHERE predictor.predictor = predictor_people.predictor
                AND people.person = predictor_people.person
                AND predictor.type = ?
            ORDER BY predictor.display_order ASC, made_predictions DESC");
        $query->execute($type);
        $people = $query->fetchall_arrayref({});
    } else {
         $query = $dbh->prepare(
           "SELECT predictor_people.predictor, is_author, made_predictions, title, first_name, second_name, email, affiliation, website
            FROM predictor, predictor_people, people
            WHERE predictor.predictor = predictor_people.predictor
                AND people.person = predictor_people.person
            ORDER BY predictor.display_order ASC, made_predictions DESC");
        $query->execute();
        $people = $query->fetchall_arrayref({});
    }

    $people = undef if (scalar @$people < 1);
    dbDisconnect($dbh) if $close_dbh;

    return $people;
}

sub getPeople {
    my ($dbh) = @_;

    my $close_dbh = (defined $dbh)?0:1;
    $dbh = dbConnect('disorder') unless defined $dbh;

    my $query = $dbh->prepare('SELECT * FROM people ORDER BY display_order ASC');
    $query->execute();
    my $people = $query->fetchall_arrayref({});
    $people = undef if (scalar @$people < 1);

    return $people;
}

1;
