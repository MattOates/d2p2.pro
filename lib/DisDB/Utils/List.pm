#!/usr/bin/env perl

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
    shuffle
    range
) ],
'rand' => [ qw(
    shuffle
) ],
'slice' => [ qw(
    range
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

=head1 NAME

DisDB::Utils::List v1.0 - Utility functions for basic list operations.

=head1 DESCRIPTION

This module has been released as part of the DisDB Project code base.

Basic list manipulation code.

=head1 EXAMPLES

#Use random list functions
use DisDB::Utils::List qw/rand/;

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

=head1 NOTICE

B<Matt Oates> (2012) shuffle and range.

=head1 LICENSE AND COPYRIGHT

B<Copyright 2012 Matt Oates>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 FUNCTIONS DEFINED

=over 4
=cut

=item * B<shuffle> - I<Fisher Yates shuffle the given parameter list, array, or arrayref content.>
=cut
sub shuffle {
    my @array = @_;

    #Small optimisation if there is only one element and its not an arrayref return it
    if (scalar @array == 1 && ref $array[0] ne 'ARRAY') {
        return (wantarray)?@array:\@array;
    }

    #If there is a single element and its an arrayref shuffle and return this in context
    if (scalar @array == 1 && ref $array[0] eq 'ARRAY') {
        @array = @{$array[0]};
    }

    #Do a normal shuffle with multiple elements
    my $current;
    for ($current = @array; --$current; ) {
        my $selected = int rand ($current+1);
        next if $current == $selected;
        #Reverse the slice between current position and the randomly selected
        $array[$current,$selected] = $array[$selected,$current];
    }

    if (wantarray) {
        return @array;
    } else {
        return \@array;
    }
}

=item B<range>( {from => $from, to => $to, by => $by, with => \@with} ) or alternatively B<range>($from, $to, $by, \@with)
Function to create a range of values, either from the series specified or that series sliced over an array.

Returns all the sliced values in range with the specified list if given.
Returns a list of integers or reals depending on the 'by' clause if no list is given to slice with.

Using the default values you can do something like:
my @list = range({to=>100}); which will act in the same way as 0..100
=cut
sub range {
        my %range;
        my ($from, $to, $by, $with) = @_;
        
        #Allow either positional...
        if (ref $from eq 'HASH') {
                %range = %{$from};
        }
        #or hash based parameters
        else {
                %range = ( from => $from, to => $to, by => $by, with => $with );
        }
        
        #Set some defaults for ease of use, e.b.  range({to=>100}) or range(undef,100)
        $range{'from'} = 0 unless defined $range{'from'};
        $range{'by'} = 1 unless defined $range{'by'};
        
        #Make sure the required from and by parameters are set, should be because of defaults, someone might have passed in undef!
        defined $range{'from'} or die 'Required parameter "from" not defined.';
        defined $range{'by'} or die 'Required parameter "by" not defined.';
        
        #Do some checks if we are slicing with an array
        if (defined $range{'with'}) {
                
                #Make sure the reference is really an array! die otherwise
                ref $range{'with'} eq 'ARRAY' or die 'Parameter "with" does not appear to be an array ref to slice with.';
                
                #If we are slicing to a given value make sure its in range of the array index we are slicing with
                if (defined $range{'to'}) {
                        'to' < scalar @{$range{'with'}} or die 'Required parameter "to" is beyond the dimensions of the list you are slicing "with".';
                }
                
                #Set the target of the range to the length of the array we are slicing with
                else {
                        $range{'to'} = scalar @{$range{'with'}} - 1;
                }
        }
        
        #Make sure the required to parameter is set
        defined $range{'to'} or die 'Required parameter "to" not defined.';
        
        #Return value
        my @list = ();
        
        #If we are slicing on the array do that
        if (defined $range{'with'}) {
                warn "Non integer 'by' term used 'with' array slice." unless $range{'by'} =~ /D/;
                for (my $i = $range{'from'}; $i <= $range{'to'}; $i += $range{'by'}) {push @list, $range{'with'}[$i]; }
        } 
        
        #Otherwise create a numerical range
        else {
                for (my $i = $range{'from'}; $i <= $range{'to'}; $i += $range{'by'}) {push @list, $i; }
        }
        
        return @list;
}

=pod

=back

=head1 TODO

=over 4

=item Add some more functions...

=back

=cut

1;
