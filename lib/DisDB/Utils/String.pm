#!/usr/bin/env perl

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
    lcp
    lcp_regi
    shard
    highlight
) ],
'lcp' => [ qw(
    lcp
    lcp_regi
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

=head1 NAME

DisDB::Utils::String v1.0 - Utility functions for basic string operations.

=head1 DESCRIPTION

This module has been released as part of the DisDB Project code base.

Basic string manipulation code.

=head1 EXAMPLES

#Use longest common prefix functions
use DisDB::Utils::String qw/lcp/;

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

=head1 NOTICE

B<Matt Oates> (2011) Longest common prefix string functions.

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

=item * B<lcp_regi(@)> - I<Find the longest common prefix of a list of strings ignoring case.>
=cut
sub lcp_regi(@) {
    #Use the first string as our assumed prefix to start.
    my $prefix = shift;
    #For every remaining string in the list chop down the prefix until it matches.
    for (@_) {
        return '' if $prefix eq '';
        chop $prefix while (! /^\Q$prefix/i); 
    }
    #If $prefix isn't the empty '' then it's by definition the longest common prefix. 
    return $prefix;
}

=item * B<lcp(@)> - I<Strictly find the longest common prefix string, sensitive to case and white space.>
=cut
sub lcp(@) {
    #Take the first string as our initial prefix estimate.
    my $prefix = shift;
    
    #Compare over all strings in the list.
    for (@_) {
        #If we have already determined there is no common prefix return.
        return '' if $prefix eq '';
        #Reduce the prefix until it matches against the current string.
        chop $prefix while ( $prefix ne substr $_, 0, length $prefix );
    }
    
    return $prefix;
}

=item * B<shard($@)> - I<Shard a string into a list of substrings using defined set of start-end pairs. First character of the string is 1.>
=cut
sub shard($@) {
    my ($string, @pairs) = @_;
    #return @{ map { substr($string, $pairs[$_][0]-1, $pairs[$_][1]-1) } 0..$#pairs };
}

=item * B<highligh($@)> - I<Shard a string into a list of substrings using defined set of start-end pairs. First character of the string is 1.>
=cut
sub highlight($@) {
    my ($string, $html, @pairs) = @_;
    $html = 'strong' unless defined $html;
    my %tag = ('open'=> "<$html>", 'close'=> "</$html>");
    my $offset = 0;

    #Flatten pairs into string breaks
    my @breaks = map { ($pairs[$_][0]-1, $pairs[$_][1]) } sort {$pairs[$a][0]-1 <=> $pairs[$b][0]-1} 0..$#pairs;

    #Add start end of string if not present
    #unshift @breaks, 0 if ($breaks[0] != 0);
    #push @breaks, (length $string)-1 if ($breaks[$#breaks] != (length $string)-1);

    #Even breaks insert open tag, 0 acts like even
    foreach my $break (0..$#breaks) {
        if ($break % 2 == 0) {
        substr($string,$breaks[$break]+$offset,0) = $tag{'open'};
        $offset += length $tag{'open'};
        } else {
             substr($string,$breaks[$break]+$offset,0) = $tag{'close'};
            $offset += length $tag{'close'};
        }
    }

    return $string;
}

=pod

=back

=head1 TODO

=over 4

=item Add some more functions...

=back

=cut

1;
