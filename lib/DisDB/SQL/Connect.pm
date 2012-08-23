#!/usr/bin/env perl
package DisDB::SQL::Connect;
use strict;
use warnings;

our $VERSION = 1.00;
use base 'Exporter';

=head1 NAME

DisDB::SQL::Connect.pm

=head1 SYNOPSIS

Connect to a database using configs

=head1 AUTHOR

Matt Oates (Matt.Oates@bristol.ac.uk)

=head1 COPYRIGHT


=head1 SEE ALSO

DisDB::Utils::Config.pm

=head1 DESCRIPTION

=cut

our %EXPORT_TAGS = (
'all' => [ qw/
			dbConnect
			dbDisconnect
/ ],
'connect' => [ qw/
			dbConnect
			dbDisconnect
/ ]
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

use DBI;
use DisDB::Utils::Config;

=pod
=head2 Methods
=over 4
=cut

sub dbConnect {
	my ($database,$host,$user,$password);
	my $c = ''; #Which database config to use

	#Auto fill from database specific config any settings the calling function didn't specify, otherwise use defaults
	if (@_) {
		($database,$host,$user,$password) = @_;
		#If a specific database config exists use it, otherwise default
		$c = (defined config("database.$database"))?"database.$database":'database';
		$database = config("$c.name") unless defined $database;
		$host = config("$c.host") unless defined $host;
		$user = config("$c.user") unless defined $user;
		$password = config("$c.password") unless defined $password;
	}
	#Use default database config
	else {
		($database,$host,$user,$password) = (config('database.name'), config('database.host'), config('database.user'),undef);
	}

	return DBI->connect("DBI:mysql:dbname=$database;host=$host"
	                                        ,$user
	                                        ,$password
	                                        ,{RaiseError =>1}
	                                    ) or die "Fatal Error: couldn't connect to $database on $host";
}

sub dbDisconnect {
	my $dbh = shift;
	return $dbh->disconnect();
}

=pod

=back

=cut

1;
