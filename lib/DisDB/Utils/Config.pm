#!/usr/bin/env perl
package DisDB::Utils::Config;
use strict;
use warnings;

our $VERSION   = 1.00;
use base 'Exporter';

my %CONFIG;
my %LOCAL_CONFIG;

our %EXPORT_TAGS = (
    'all' => [ qw/config local_config/ ],
);
our @EXPORT    = @{$EXPORT_TAGS{'all'}};
our @EXPORT_OK = qw//;

=head1 NAME

DisDB::Utils::Config.pm

=head1 DESCRIPTION

Provides global configuration information.
Loads in the data from ~/.global_config.ini into %CONFIG as well as any local ./config.ini into %LOCAL_CONFIG in the working directory of the currently executing script.
If no global config is found a sensible default from inside the package will be given. Failing this you will just run without a config.

=head2 %CONFIG

A configuration hash with similar structure to the INI definition found in the .global_config.ini file of your home.
Example use: `%CONFIG{'database.name'}`
Be aware this variable is tied to the file, so if you make a change to the hash you are editing the file too.

=head2 %LOCAL_CONFIG

A configuration hash with similar structure to the INI definition found in the local ./config.ini file.
As with %CONFIG this variable is tied to the local config file to reflect changes made programatically.
=cut

use Carp;
use Config::Simple;
use File::Basename;

BEGIN {
#Load in the local config for the invoking script if it exists.
if ( -e "config.ini" ) {
   tie %LOCAL_CONFIG, "Config::Simple", "config.ini";
}

#Where is this module located
my (undef,$mod_path,undef) = fileparse(__FILE__);

#Use the users home supfam_config.ini over anything else
if ( -e $ENV{'HOME'}."/.global_config.ini") {
   tie %CONFIG, "Config::Simple", $ENV{'HOME'}."/.global_config.ini";
}
#Use the config in the current working directory useful for CGI scripts that dont have a home
elsif (-e ".global_config.ini") {
   tie %CONFIG, "Config::Simple", ".global_config.ini";
}
#Try to load the default from the Utils package
elsif (-e $mod_path."global_config.ini") {
   tie %CONFIG, "Config::Simple", $mod_path.'global_config.ini';
}
#Warn that we don't have a config for the package
else {
   carp "Cannot locate the global global_config.ini for Supfam:: modules, looking in: ".$ENV{'HOME'}."/.global_config.ini or ".$mod_path.'global_config.ini';
}
}

sub config {
    my $key = shift;
    return $CONFIG{$key};
}

sub local_config {
    my $key = shift;
    return $LOCAL_CONFIG{$key};
}

1;
__END__
