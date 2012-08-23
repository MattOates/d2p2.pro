#!/usr/bin/env perl

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
    hsv2rgb
    colourset
) ],
'convert' => [ qw(
    hsv2rgb
) ],
'generate' => [ qw(
    colourset
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

=head1 NAME

DisDB::Utils::Colours v1.0 - Utility functions for colour palette operations.

=head1 DESCRIPTION

This module has been released as part of the DisDB Project code base.

Basic colour manipulation code.

=head1 EXAMPLES

#Use colour conversion functions
use DisDB::Utils::Colours qw/convert/;

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

=head1 NOTICE

B<Matt Oates> (2012) colourset and hsv2rgb.

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

=item hsv2rgb($Hue, $Saturation, $Value)
Function to convert HSV colour space values to RGB colour space.
Returns RGB value as [R,G,B]
=cut
sub hsv2rgb {
        my ($Hue,$Saturation,$Value) = @_;
        my ($Red,$Green,$Blue) = (0,0,0);
        
        #Check the input and warn if it's a bit wrong
        warn "Invalid Hue component of HSV colour passed, with value: $Hue." unless ($Hue >= 0.0 and $Hue <= 360.0);
        warn "Invalid Saturation component of HSV colour passed, with value: $Saturation." unless($Saturation >= 0.0 and $Saturation <= 1.0);
        warn "Invalid Value component of HSV colour passed, with value: $Value." unless ($Value >= 0.0 and $Value <= 1.0);
        
        #If colour has no saturation return greyscale RGB
        if ($Saturation == 0) {
                $Red = $Green = $Blue = $Value;
                return [$Red, $Green, $Blue];
        }
        
        #Partition the Hue into the 5 different colour chroma and then map each of these to RGB based on the colour theory
        $Hue /= 60.0;
        my $Chroma = floor($Hue) % 6; 
        my $H_d = $Hue - $Chroma; 
        
        #RGB cube components
        my ($I,$J,$K) = ( $Value * ( 1 - $Saturation ),
                                   $Value * ( 1 - $Saturation * $H_d ),
                                   $Value * ( 1 - $Saturation * ( 1 - $H_d ) )
                                    );
        
        #Map components to RGB values per chroma
        if ($Chroma == 0) { ($Red,$Green,$Blue) = ($Value,$K,$I); }
        elsif ($Chroma == 1) { ($Red,$Green,$Blue) = ($J,$Value,$I); }
        elsif ($Chroma == 2) { ($Red,$Green,$Blue) = ($I,$Value,$K); }
        elsif ($Chroma == 3) { ($Red,$Green,$Blue) = ($I,$J,$Value); }
        elsif ($Chroma == 4) { ($Red,$Green,$Blue) = ($K,$I,$Value); }
        else{ ($Red,$Green,$Blue) = ($Value,$I,$J); }
        
        #Return the RGB value in the integer range [0,255] rather than real [0,1]
        return [floor($Red * 255),floor($Green * 255),floor($Blue * 255)];
}

=item colourset($num_colours, $method)
Function to grab a set of well spaced colours from an HSV colour wheel.
    $num_colours - The number of colour values to produce, must be greater than 0 but no bigger than 360
    $method - The method for selecting colours over HSV colour space, either 'equal_spacing' or for around 10 colours 'chroma_bisection' is better.
Returns an array of RGB values of the form ([R,G,B]) and undef on $num_colours out of bounds
=cut
sub colourset {
    use DisDB::Utils::List qw/shuffle/
        my ($num_colours,$method) = @_;
        if ($num_colours <= 0 or $num_colours > 360) {
                warn "Number of colours requested out of bounds.";
                return undef;
        }
        $method = 'chroma_bisection' unless $method;
        
        #Colours to return
        my %colours;
        
        #Default Hue Saturation and Value, saturation of 0.65 gives a more pastel feel!
        my ($Hue, $Saturation, $Value) = (0.0,0.65,1.0);
        
        #The interval to space colours around the wheel if equal
        my $hsv_interval = 360 / $num_colours;
        
        #Array of degrees for reuse to create ranged arrays with a given interval
        my @degrees = 1..360;
        
        #Iteratively bisect each chroma segment so that the first 6 colours are well spaced perceptually.
        #However after 12 colours we will have increasing pairs that are more confused as 
        #they are increasingly close to each other compared to the rest of the colours!
        #To get around this problem of selecting closely around a single bisection, we jump around the 
        #chroma randomly sampling.
        if ($method eq 'chroma_bisection') {
                #The current cycle of chroma bisection
                my $hsv_cycle = 1;
                #Number of colours selected by bisecting chroma so far
                my $colours_selected = 0;
                
                #While we still have colours to select
                while ($colours_selected != $num_colours) {
                        #Work out the size of interval to use this cycle around the wheel
                        $hsv_interval = 60 / $hsv_cycle;
                        #Get all the Hues for this cycle that haven't already been examined and are on the line of bisection
                        my @Hues = grep { (not $_ % $hsv_interval) && (not exists $colours{$_%360}) } @degrees;
                        #Shuffle so that we don't take from around the same chroma all the time, only perceptually worthwhile after 12th colour
                        shuffle(\@Hues) if $hsv_cycle > 2;
                        
                        #While we still have hues to select from in this cycle
                        while (@Hues) {
                                #Finish if we have enough colours
                                last if $colours_selected == $num_colours;
                                #Consume a Hue from this cycle
                                $Hue = shift @Hues;
                                #360 should be 0 for red
                                $Hue %= 360;
                                #Store this Hue and mark selection
                                $colours{$Hue} = hsv2rgb($Hue,$Saturation,$Value) ;
                                $colours_selected++;
                        }
                        $hsv_cycle++;
                }
        }
        
        #Just space colours even distances apart over the HSV colour wheel.
        #You have slightly odd/garish colours coming out, but you dont get uneven perceptual distance
        #between pairs of colours. This scales far better despite the horrible colours.
        elsif ($method eq 'equal_spacing') {    
                foreach $Hue (1..$num_colours) {
                        $Hue = ($Hue * $hsv_interval) % 360;
                        $colours{$Hue} = hsv2rgb($Hue,$Saturation,$Value) ;
                }
        }
        
        #Otherwise return nothing and warn the programmer
        else {
                warn "Colourset method not known, use either 'equal_spacing' or for fewer colours 'chroma_bisection'";
                return undef;
        }
        
        #Shuffle final colours so that even if we do use chroma_bisection closer colours will hopefully not be sequential
        @_ = values %colours;
        shuffle(\@_);
        return @_;
}

=pod

=back

=head1 TODO

=over 4

=item Add some more functions...

=back

=cut

1;
