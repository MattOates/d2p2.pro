package DisDB::SQL;
require Exporter;
require SelfLoader;

=head1 NAME

DisDB::SQL::TopicAllocation.pm

=head1 SYNOPSIS

Package for investigating SUPERFAMILY domain combinations.

=head1 AUTHOR

Matt Oates (Matt.Oates@bristol.ac.uk)

=head1 COPYRIGHT

Copyright 2012 Matt Oates, University of Bristol.

=head1 SEE ALSO

DisDB::SQL::Functions.pm - Where assorted SQL related basic functions are kept.

=head1 DESCRIPTION

=cut

our @ISA = qw(Exporter SelfLoader);

#our %EXPORT_TAGS = ( 'all' => [ qw(
#getProteinImportance
#getDomainImportance
#) ] );
#our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT_OK = qw(getProteinImportance getDomainImportance);
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

use Carp;

use DisDB::SQL::Functions qw(getProteinIDFromUP getProteinArchitectures doArchitectureTF_IDF doDomainTF_IDF);

1;

__DATA__

=pod
=head2 Methods
=over 4
=cut


=pod
=item * getProteinImportance($list_of_up_ids, $dbh_optional)
Returns a hashref of all the proteins with supfam protein id, their domain architectures and their tf-idf importance.
=cut
sub getProteinImportance {
my ($up_ids, $dbh) = @_;
ref $up_ids eq "ARRAY" or die "Expected an ARRAY ref $!";
$dbh = Supfam::SQLFunc::dbConnect() unless defined $dbh;
my $close_dbh = (@_ > 1)?1:0;

my $ranked_proteins = {};

    my $proteins = getProteinIDFromUP($up_ids,$dbh);

    #Get the unique protein ids so we only fetch the architectures once
    #my @sf_pids = keys %{{ map { $_ => undef } values %$proteins }}; #Kinda slow, laughably called a perl "idiom"
   #Faster implementation exploiting some perl internals for hash construction
   my @sf_pids = do { my %uniq; @uniq{values %$proteins}=undef; keys %uniq; };

   #Get the architecture assignments for these proteins from the SUPERFAMILY database
    my $architectures = getProteinArchitectures(\@sf_pids,$dbh);
   
   #Get the frequencies of each architecture from the input set of proteins
   my $arch_frequencies = {};
   map {$arch_frequencies->{$_}++} values %$architectures;

    foreach my $id (@$up_ids) {
        my $arch = $architectures->{$proteins->{$id}};
        my $term_freq = $arch_frequencies->{$arch}; #Term frequencies from our input set of proteins
        my $importance = doArchitectureTF_IDF($arch,$term_freq,$dbh);
      $ranked_proteins->{$id}{'arch'} = $arch;
      $ranked_proteins->{$id}{'pid'} = $proteins->{$id};
      $ranked_proteins->{$id}{'tf'} = $term_freq;
      $ranked_proteins->{$id}{'tf-idf'} = $importance;
    }

dbDisconnect($dbh) if $close_dbh;
return $ranked_proteins;

}


=pod
=item * getDomainImportance($sf_id)
Returns a hashref of all the protein ids with their domain assignments and their tf-idf importance.
=cut
sub getDomainImportance {
my ($domains, $dbh) = @_;
ref $domains eq "ARRAY" or die "Expected an ARRAY ref $!";
$dbh = Supfam::SQLFunc::dbConnect() unless defined $dbh;
my $close_dbh = (@_ > 1)?1:0;

   my $ranked_domains = {};
   map {$ranked_domains->{$_}{'tf'}++} @$domains;

   foreach $id (keys %$ranked_domains) {
      $ranked_domains->{$id}{'tf-idf'} = doDomainTF_IDF($id,$ranked_domains->{$id}{'tf'},$dbh);
   }

dbDisconnect($dbh) if $close_dbh;
return $ranked_domains;
}

=pod

=back

=cut
