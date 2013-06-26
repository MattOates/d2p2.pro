#!/usr/bin/env perl

use warnings;
use strict;

=head1 NAME

B<archpic.cgi> - Display the architecture for a specified SUPERFAMILY protein.

=head1 DESCRIPTION

Outputs an SVG rendering of the given proteins structual and disordered architecture. Weaker hits are included with their e-values specified as 'hanging' blocks.

An example use of this script is as follows:

To emulate SUPERFAMILY genome page style figures as closely as possible include something similar to the following in the page:

<div width="100%" style="overflow:scroll;">
	<object width="100%" height="100%" data="/cgi-bin/disorder.cgi?proteins=3385949&genome=at&supfam=1&ruler=0" type="image/svg+xml"></object>
</div>

To have super duper Matt style figures do something like:

<div width="100%" style="overflow:scroll;">
	<object width="100%" height="100%" data="/cgi-bin/disorder.cgi?proteins=3385949,26711867&callouts=1&ruler=1&disorder=1" type="image/svg+xml"></object>
</div>


=head1 TODO

B<HANDLE PARTIAL HITS!>

I<SANITIZE INPUT MORE!>

	* Specify lists of proteins, along with other search terms like comb string, required by SUPERFAMILY.

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

=head1 NOTICE

B<Matt Oates> (Jan 2012) First features added.

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

=head1 FUNCTIONS

=over 4

=cut

use POSIX qw/ceil floor/;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use Data::Dumper;
use DBI;
use JSON::XS;

#Deal with the CGI parameters here
my $cgi = CGI->new;

#Specify protein seqid labels for a given set of genomes where possible, default is all seqids
my $genome = (defined $cgi->param('genome'))?$cgi->param('genome'):undef;

#Specify a list of comb ids
my $combids = (defined $cgi->param('combids'))?$cgi->param('combids'):undef;

#Specify a list of seqids
my $seqids = (defined $cgi->param('seqids'))?$cgi->param('seqids'):undef;

#Protein ID list to display figures for
my $proteins = (defined $cgi->param('proteins'))?$cgi->param('proteins'):'';#'3,4,3385949,26711867,10364754';
$proteins =~ s/[^\d,]//g;

#Add on the seqids to the list of proteins
if (defined $seqids) {
	if ($proteins) {
		$proteins = join ',',seqid_to_protein([split /,/, $seqids],$genome), $proteins;
	}
	else {
		$proteins = join ',',seqid_to_protein([split /,/, $seqids],$genome);
	}
}

#Add on the combids to the list of proteins
if (defined $combids) {
	error("Genome Undefined") unless defined $genome;
	$combids =~ s/[^\d,]//g;
	if ($proteins) {
		$proteins = join ',',comb_to_protein([split /,/, $combids],$genome), $proteins;
	}
	else {
		$proteins = join ',',comb_to_protein([split /,/, $combids],$genome);
	}
}

#What colouring scheme should we use (deprecated)
my $colouring = (defined $cgi->param('colouring'))?$cgi->param('colouring'):undef;

#Don't include structure!
my $nostruct = (defined $cgi->param('nostruct'))?$cgi->param('nostruct'):undef;

#Should we render disorder hits?
my $draw_disorder = (defined $cgi->param('disorder'))?$cgi->param('disorder'):1;
my $draw_experiments = (defined $cgi->param('experiment'))?$cgi->param('experiment'):1;
my $draw_dis_probs = (defined $cgi->param('probs'))?$cgi->param('probs'):undef;
my $draw_binding = (defined $cgi->param('binding'))?$cgi->param('binding'):1;
my $draw_consensus = (defined $cgi->param('consensus'))?$cgi->param('consensus'):1;
my $draw_conflicts = (defined $cgi->param('conflicts'))?$cgi->param('conflicts'):1;

#Should we draw PTMs?
my $draw_ptms = (defined $cgi->param('ptms'))?$cgi->param('ptms'):1;

#Is this a for-print rendering or for the web
my $forprint = (defined $cgi->param('forprint'))?1:0;
my $scale= (defined $cgi->param('scale'))?$cgi->param('scale'):2;
my $download = (defined $cgi->param('download'))?1:0;

#Downloading assumes printed output
$forprint = 1 if ($download);

#Do you want textual labels for a key?
my $draw_labels = (defined $cgi->param('labels'))?$cgi->param('labels'):1;
my $supfam_labels = (defined $cgi->param('supfam'))?$cgi->param('supfam'):0;

#If we want SUPERFAMILY labels then we dont want to show weak hits!
my $include_weak_hits = (defined $cgi->param('weak'))?$cgi->param('weak'):0;
$include_weak_hits = ($supfam_labels)?0:$include_weak_hits;

#Do you want callout boxes around those labels, looke more web 2.0!
my $draw_callouts = (defined $cgi->param('callouts'))?$cgi->param('callouts'):1;
$draw_labels = 1 if ($draw_callouts); #Callouts imply labels but not vice versa

#Do you want a key at the end of the figure
my $draw_key = (defined $cgi->param('key'))?$cgi->param('key'):1;

#Should we have a protein co-ordinate ruler included
my $draw_ruler = (defined $cgi->param('ruler'))?$cgi->param('ruler'):1;

#Force conversion to PNG, currently based on browser support for SVG
my $force_png = (defined $cgi->param('png'))?1:0;
#Force PNG if Internet Explorer is requesting an image, even if we didn't say so
#$force_png = ($ENV{HTTP_USER_AGENT} =~ /IE/)?1:$force_png;

#If we dont have any proteins to draw print out an empty SVG
if (not $proteins) {
	error("No Proteins Found");
}

#Global variables
my %sf_details;
my %predictor_details;
my $num_predictors;
my %protein_details;
my %ptm_details;
my %experiments;
my $output = '';

my $current_record = 0;
my $ruler_width = 0;

#Database access
my $db_user = 'oates';
my $db_password = '';
my $db_host = 'localhost';
my $disorder_db = 'disorder';
my $superfamily_db = 'superfamily';

#Formatting config variables
my $min_width = ($draw_disorder)?500:400; #Deal with short proteins having their SF labels cut short
my $key_size = 100;
my $weak_below = 15; #How far below do you want weaker sf hits, negative is above
my $weak_note = ' (weak support)'; #What should be appended to the structure popup title if its a weaker hit
my $xpad = 5; #left indentation
my $ypad = 5; #top indentation
my $record_height = 250; #how much spacing for a single protein record
my $record_spacing = 20;
my $dy = $record_height/2; #with the amino acid chain in the middle to begin with, this is a cursor for the vertical position reused in each draw function
my $disorder_height = 7; #Height of disordered blocks around the amino line
my $disorder_spacing = 15;
my $binding_height = 5;
my $structure_height = 10; #Height of each structural block around the amino line
my $ptm_size = 10; #Size of the PTM dots
my $ptm_levels = 4; #Different levels the PTM dots can be binned
my %ptm_colours = ('ACETYLATION' => 'yellow','DI-METHYLATION' => 'blue','METHYLATION' => 'blue','MONO-METHYLATION' => 'blue','O-GlcNAc' => 'orange','PHOSPHORYLATION' => 'red','SUMOYLATION' => 'green','TRI-METHYLATION' => 'blue','UBIQUITINATION' => 'purple');
my %ptm_abrev = ('ACETYLATION' => 'A','DI-METHYLATION' => 'M2','METHYLATION' => 'M','MONO-METHYLATION' => 'M1','O-GlcNAc' => 'G','PHOSPHORYLATION' => 'P','SUMOYLATION' => 'S','TRI-METHYLATION' => 'M3','UBIQUITINATION' => 'U','PTM' => '?');

=item B<error>

	Print out a CGI error message with HTTP status 204 No Content
=cut
sub error  {
	my ($error) = @_;
	print $cgi->header('type'=>'text/html', 'status'=>'204 No Content');
	print "<html><body><h1>$error</h1></body></html>";
	exit;
}

=item B<range(> {from => $from, to => $to, by => $by, with => \@with} B<)> or alternatively B<range($from, $to, $by, \@with)>

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

=item B<hsv2rgb($Hue, $Saturation, $Value)>

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

=item B<colourset($num_colours, $method)>

	Function to grab a set of well spaced colours from an HSV colour wheel.
		$num_colours - The number of colour values to produce, must be greater than 0 but no bigger than 360
		$method - The method for selecting colours over HSV colour space, either 'equal_spacing' or for around 10 colours 'chroma_bisection' is better.
	Returns an array of RGB values of the form ([R,G,B]) and undef on $num_colours out of bounds
=cut
sub colourset {
	my ($num_colours,$method) = @_;
	if ($num_colours <= 0 or $num_colours > 360) {
		warn "Number of colours requested out of bounds.";
		return undef;
	}
	$method = 'chroma_bisection' unless $method;
	
	#Internal sub to randomly shuffle an array
	sub fisher_yates_shuffle {
		my ($array) = @_;
		my $current;
		for ($current = @$array; --$current; ) {
			my $selected = int rand ($current+1);
			next if $current == $selected;
			#Reverse the slice between current position and the randomly selected
			@$array[$current,$selected] = @$array[$selected,$current];
		}
		return $array;
	}
	
	#Colours to return
	my %colours;
	
	#Default Hue Saturation and Value, saturation of 0.65 gives a more pastel feel!
	my ($Hue, $Saturation, $Value) = (0.0,0.65,0.95);
	
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
			my @Hues = grep { not exists $colours{$_%360} } range({ from => 1, to => 360, by => $hsv_interval});
			#Shuffle so that we don't take from around the same chroma all the time, only perceptually worthwhile after 12th colour
			fisher_yates_shuffle(\@Hues) if $hsv_cycle > 2;
			
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
	#fisher_yates_shuffle(\@_);
	return @_;
}

=item B<comb_to_protein>

	Convert combids to unique protein ids
=cut
sub comb_to_protein {
	my ($combs,$genome) = @_;
	my %proteins = ();
	#my $dbh= DBI->connect("dbi:mysql:database=superfamily;host=$db_host",$db_user,$db_password) or die $DBI::errstr;	
	my $dbh= DBI->connect("dbi:mysql:database=superfamily;host=localhost",'oates',undef) or die $DBI::errstr;

	foreach my $comb (@$combs) {
		my $result = $dbh->selectall_arrayref("select distinct protein.protein from comb, protein where comb.protein = protein.protein and protein.genome = ? and comb_id = ?;", undef, $genome, $comb);
		foreach my $protein (@$result) {
			$proteins{$protein->[0]}++;
		}
	}
	return keys %proteins;
}

=item B<seqid_to_protein>

	Convert seqids to unique protein ids
=cut
sub seqid_to_protein {
	my ($seqs,$genome) = @_;
	my %proteins = ();
	#my $dbh= DBI->connect("dbi:mysql:database=superfamily;host=$db_host",$db_user,$db_password) or die $DBI::errstr;	
	my $dbh= DBI->connect("dbi:mysql:database=superfamily;host=localhost",'oates',undef) or die $DBI::errstr;

	foreach my $seq (@$seqs) {
        my $result;
        if ($genome) {
		   $result = $dbh->selectall_arrayref("select distinct protein from protein where genome = ? and seqid = ?;", undef, $genome, $seq);
        } else {
		   $result = $dbh->selectall_arrayref("select distinct protein from protein, genome where protein.genome = genome.genome and seqid = ?;", undef, $seq);
        }
		foreach my $protein (@$result) {
			$proteins{$protein->[0]}++;
		}
	}
	return keys %proteins;
}

=item B<get_details>

	Populate the %protein_details and %sf_details hashes from the SQL database, all SQL is in here.
	Additionally the pallette of colours for the sf hit blocks is defined.
=cut
sub get_details {
	my $dbh= DBI->connect("dbi:mysql:database=;host=$db_host",$db_user,$db_password) or die $DBI::errstr;
	my $sf_index = 1;
	foreach my $protein (split /,/, $proteins) {
		next if exists $protein_details{$protein};
		$protein_details{$protein} = {};
		
		#Get the proteins length from the genome_sequence table
		($protein_details{$protein}{'length'}) = $dbh->selectrow_array("SELECT length FROM $superfamily_db.genome_sequence WHERE protein = ?", undef, $protein);
				
		#Get the genome and seqid for a given protein, limit by the specified genome if given
		$protein_details{$protein}{'names'} = '';
		if ($genome) {
			my $result = $dbh->selectall_arrayref("SELECT protein.genome, protien.seqid FROM $superfamily_db.protein, $superfamily_db.genome WHERE genome.genome = protein.genome AND genome.include='y' AND protein = ? AND genome = ?", undef, $protein, $genome);
			$protein_details{$protein}{'names'} = $result;
		}
		else {
			my $result = $dbh->selectall_arrayref("SELECT protein.genome, protein.seqid FROM $superfamily_db.protein, $superfamily_db.genome WHERE genome.genome = protein.genome AND genome.include='y' AND protein = ? ORDER BY genome DESC", undef, $protein);
			$protein_details{$protein}{'names'} = $result;
		}
		
		#Get all the disordered hits 
		if ($draw_disorder) {
			my $disordered_hits = $dbh->selectall_arrayref("SELECT dis_assignment.start, dis_assignment.end, dis_assignment.predictor FROM $disorder_db.dis_assignment WHERE protein = ? ORDER BY start ASC", undef, $protein);
			$protein_details{$protein}{'disorder'} = [];
			foreach (@$disordered_hits) {
				push @{$protein_details{$protein}{'disorder'}}, $_;
			}
            %predictor_details = %{$dbh->selectall_hashref("SELECT predictor, colour, has_probs, name, type, display_order, include FROM $disorder_db.predictor;", 'predictor')};
            
            if ($draw_consensus or $draw_conflicts) {
			    my ($cons, $conf) = $dbh->selectrow_array("SELECT consensus, conflict FROM $disorder_db.protein_consensus_conflict WHERE protein = ?", undef, $protein);
                if ($cons) {

                    #TODO remove this hack that deals with broken JSON records for very long proteins (Titin et al.)
                    if ($cons =~ m/[^\]]$/) {
                        chop $cons;
                        $cons .= ']';
                    }
                    if ($conf =~ m/[^\]]$/) {
                        chop $conf;
                        $conf .= ']';
                    }

                    $protein_details{$protein}{'consensus'} = decode_json($cons); 
                    $protein_details{$protein}{'conflict'} = decode_json($conf); 
                }
            }

            if ($draw_consensus) {
                my $ranges = $dbh->selectall_arrayref("SELECT start, end FROM $disorder_db.dis_consensus_assignment WHERE protein = ? AND cutoff = 1.0",undef,$protein);
                if ($ranges) {
                    $protein_details{$protein}{'consranges'} = $ranges; 
                }
            }

            $num_predictors = scalar grep {$predictor_details{$_}{type} eq 'disorder' and $predictor_details{$_}{include} eq 1 } keys %predictor_details;
            
		}

        if ($draw_experiments) {
            my ($num_experiments) = $dbh->selectrow_array("SELECT COUNT(DISTINCT db_id) AS num FROM $disorder_db.dis_experiment WHERE protein = ?",undef,$protein);
            $protein_details{$protein}{'num_experiments'} = $num_experiments;
            my $experiments = $dbh->selectall_arrayref("
                    SELECT name, db_id, start, end, up_id, classification, REPLACE(protein_link, '%protein%', db_id)
                    FROM $disorder_db.dis_experiment, $disorder_db.external_db
                    WHERE protein = ? 
                    AND dis_experiment.external_db = external_db.external_db
                    ORDER BY dis_experiment.external_db, db_id, start ASC", undef, $protein);
            if ($experiments and scalar @$experiments) {
                foreach my $region (@$experiments) {
                    my ($name, $db_id, @details) = @$region;
                    $experiments{$protein}{$name}{$db_id} = [] unless exists $experiments{$protein}{$name}{$db_id};
                    push @{$experiments{$protein}{$name}{$db_id}}, \@details;
                }
            }
        }

        if ($draw_binding) {
		    my $binding_hits = $dbh->selectall_arrayref("SELECT binding_assignment.start, binding_assignment.end, binding_assignment.predictor FROM $disorder_db.binding_assignment WHERE protein = ? ORDER BY start ASC", undef, $protein);
			$protein_details{$protein}{'binding'} = [];
			foreach (@$binding_hits) {
				push @{$protein_details{$protein}{'binding'}}, $_;
			}

        }
		
        unless ($nostruct) {
            #Get strong hits to structure from the SUPERFAMILY ass table
            my $structured_hits = $dbh->selectall_arrayref("SELECT sf, region, evalue, description FROM $superfamily_db.ass, $superfamily_db.des WHERE des.id = ass.sf AND evalue <= 0.0001 AND protein = ? ORDER BY evalue ASC",undef,$protein);
            $protein_details{$protein}{'structures'}{'strong'} = [];
            foreach (@$structured_hits) {
                unless (exists $sf_details{$_->[0]}) {
                    $sf_details{$_->[0]}{'label'} = $sf_index;
                    $sf_details{$_->[0]}{'description'} = $_->[3];
                    $sf_index++ unless $supfam_labels;
                }
                $sf_index++ if $supfam_labels;
                push @{$protein_details{$protein}{'structures'}{'strong'}}, $_;
            }
            
            #Get weaker hits to structure from the SUPERFAMILY ass table
            if ($include_weak_hits) {
                my $structured_lower_hits = $dbh->selectall_arrayref("SELECT sf, region, evalue, description FROM $superfamily_db.ass, $superfamily_db.des WHERE des.id = ass.sf AND evalue > 0.0001 AND evalue <= 0.01 AND protein = ?",undef,$protein);
                $protein_details{$protein}{'structures'}{'weak'} = [];
                foreach (@$structured_lower_hits) {
                    unless (exists $sf_details{$_->[0]}) {
                        $sf_details{$_->[0]}{'label'} = $sf_index;
                        $sf_details{$_->[0]}{'description'} = $_->[3];
                        $sf_index++;
                    }
                    push @{$protein_details{$protein}{'structures'}{'weak'}}, $_;
                }
            }
        }

        if ($draw_ptms) {
            next if exists $ptm_details{$protein};
            $ptm_details{$protein} = [];
            my $ptms = $dbh->selectall_arrayref("SELECT locus,type,(disorder_predictions > 0),group_id,seq,amino FROM $disorder_db.ptm_assignment WHERE protein = ? ORDER BY locus ASC",undef,$protein);
            foreach my $ptm (@$ptms) {
                push @{$ptm_details{$protein}},  {'locus' => $ptm->[0],'type' => $ptm->[1], 'disordered' => $ptm->[2], 'group_id' => $ptm->[3], 'seq' => $ptm->[4], 'amino' => $ptm->[5]};
            }
        }
	}
	$dbh->disconnect or die $DBI::errstr;
	
	#Get as many colours as there are superfamilies for this diagram
	my @colours = colourset(scalar keys %sf_details,$colouring);
	my $colour = 0;
	foreach my $sf (keys %sf_details) {
	    $sf_details{$sf}{'colour'} = "rgb(".$colours[$colour][0].','.$colours[$colour][1].','.$colours[$colour][2].")";
	    $colour++;
	}
}

=item B<header>

	Output the SVG header with some JavaScript for performing mouse popup information
=cut
sub header {
	my ($width, $height) = @_;
    $width *= $scale;
    $height *= $scale;
	my $header = <<EOF;
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" 
	 "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="$width" height="$height"
     viewBox="0 0 $width $height"
     preserveAspectRatio="xMidYMid meet"
     onload="init(evt)">
EOF

    unless ($forprint or $force_png) {
    $header .= <<EOF;
     <script type="text/ecmascript"><![CDATA[
      var svg_document, svg_root;
      var tooltop, tip_box, tip_title, tip_text;
      var hit_range, hit_quality;

      function init(evt) {
	 svg_document = evt.target.ownerDocument;
	 svg_root = document.documentElement;

	 tooltip = svg_document.getElementById('tooltip');
	 tip_box = svg_document.getElementById('tip_box');
	 tip_text = svg_document.getElementById('tip_text');
	 tip_title = svg_document.getElementById('tip_title');
	 tip_desc = svg_document.getElementById('tip_desc');
	 hit_range = svg_document.getElementById('hit_range');
	 hit_quality = svg_document.getElementById('hit_quality');

      };

      function show_tip(evt) {
	  var x = evt.clientX + window.pageXOffset;
	  var y = evt.clientY + window.pageYOffset;
	  var hit = evt.target;

	  var title_text = hit.getElementsByTagName('name').item(0);
	  if (! title_text ) {
	     return false;
	  }

	  title_text = title_text.firstChild.nodeValue;
	  tip_title.firstChild.nodeValue = title_text;
	  tip_title.setAttributeNS(null, 'display', 'inline' );

	  var description_text = hit.getElementsByTagName('desc').item(0);
	  if (description_text) {
	     description_text = description_text.firstChild.nodeValue;
	     tip_desc.firstChild.nodeValue = description_text;
	     tip_desc.setAttributeNS(null, 'display', 'inline' );
	  }
	  else {
	     tip_desc.setAttributeNS(null, 'display', 'none' );
	  }

	  var range_text = hit.getElementsByTagName('range').item(0);
	  if (range_text) {
	     range_text = range_text.firstChild.nodeValue;
	     hit_range.firstChild.nodeValue = range_text;
	     hit_range.setAttributeNS(null, 'display', 'inline' );
	  }
	  else {
	     hit_range.setAttributeNS(null, 'display', 'none' );
	  }

	  var quality_text = hit.getElementsByTagName('quality').item(0);
	  if (quality_text) {
	     quality_text = quality_text.firstChild.nodeValue;
	     hit_quality.firstChild.nodeValue = quality_text;
	     hit_quality.setAttributeNS(null, 'display', 'inline' );
	  }
	  else {
	     hit_quality.setAttributeNS(null, 'display', 'none' );
	  }

	  tip_title.firstChild.nodeValue = title_text;
	  tip_desc.firstChild.nodeValue = description_text;
	  hit_range.firstChild.nodeValue = range_text;
	  hit_quality.firstChild.nodeValue = quality_text;
	  
	  var box = tip_text.getBBox();
	  tip_box.setAttributeNS(null, 'width', Number(box.width) + 10);
	  tip_box.setAttributeNS(null, 'height', Number(box.height) + 10);
	  
	  tooltip.setAttributeNS(null, 'transform', 'translate(' + x + ',' + y + ')');
	  tooltip.setAttributeNS(null, 'visibility', 'visible');
      };


      function hide_tip(evt) {
	  tooltip.setAttributeNS(null, 'visibility', 'hidden');
      };

   ]]></script>
EOF
    }

    $header .= <<EOF;
  <defs>
    <linearGradient id="disorder"
		    x1="0%" y1="0%"
		    x2="0%" y2="100%"
		    spreadMethod="pad">
      <stop offset="0%"   stop-color="#cccccc" stop-opacity="0.6"/>
      <stop offset="100%" stop-color="#666666" stop-opacity="0.6"/>
    </linearGradient>
    <radialGradient id="radial-glow"
            fx="40%"
            fy="40%"
            r="55%"
            spreadMethod="pad">
        <stop offset="0%"   stop-color="#cccccc" stop-opacity="0.5" />
        <stop offset="100%" stop-color="#cccccc" stop-opacity="0.01" />
    </radialGradient>
    <filter id="emboss" >
        <feGaussianBlur in="SourceAlpha" stdDeviation="2" result="blur"/>
        <feSpecularLighting in="blur" surfaceScale="-3" style="lighting-color:white" specularConstant="1" specularExponent="16" result="spec" kernelUnitLength="1" >
            <feDistantLight azimuth="45" elevation="45" />
        </feSpecularLighting>
        <feComposite in="spec" in2="SourceGraphic" operator="in" result="specOut"/>
    </filter>
        <pattern id="binding" x="0" y="0" width="5" height="5"
        patternUnits="userSpaceOnUse">
        <path d="M 0 0 Q .25 5 2.5 2.5 T 5 5"
            style="stroke: black; fill: none;"/>
        </pattern>
  </defs>
  <g transform="translate($xpad,$ypad) scale($scale)">
EOF
}

=item B<footer>

	Print out the SVG footer containing the tooltip popup XML
=cut
sub footer {
	my $footer = <<EOF;
   </g>
EOF
	unless ($force_png or $forprint) {
	$footer .= <<EOF;
   <g id='tooltip' opacity='0.8' visibility='hidden' pointer-events='none'>
      <rect id='tip_box' x='0' y='5' width='88' height='20' rx='2' ry='2' fill='white' stroke='black'/>
      <text id='tip_text' x='5' y='20' font-family='Arial' font-size='10'>
        <tspan id='tip_title' x='5' font-weight='bold' text-decoration="underline"><![CDATA[]]></tspan>
	    <tspan id='hit_range' x='5' dy='15' fill='red'><![CDATA[]]></tspan>
        <tspan id='hit_quality' x='5' dy='10' fill='green'><![CDATA[]]></tspan>
	    <tspan id='tip_desc' x='5' dy='10' fill='blue'><![CDATA[]]></tspan>
      </text>
   </g>
EOF
    }
	$footer .= <<EOF;
</svg>
EOF
	return $footer;
}

=item B<callout($x,$y,$label)>

	Returns the string for drawing a callout at a given position filled with $label.
=cut
sub callout {
	my ($x,$y,$label) = @_;
	my $width = length $label;
	return "<path style=\"fill:#ffffff;fill-opacity:0.7;stroke:#000000;stroke-width:0.5;stroke-linejoin:round;stroke-opacity:1\" d=\"M $x,$y L "
					.($x+2.5).",".($y+2.5)
					." L ".($x+(5*$width)).",".($y+2.5)
					." L ".($x+(5*$width)).",".($y+17)
					." L ".($x-(5*$width)).",".($y+17)
					." L ".($x-(5*$width)).",".($y+2.5)
					." L ".($x-2.5).",".($y+2.5)
				." Z\" />";
}

=item B<draw_disorder($protein)>

	Draw all the disorder hits for a protein
=cut
sub draw_disorder {
	my ($protein) = @_;
	my $result = '';
	my $middle = $dy + ($record_height / 2)-$disorder_spacing;
	
	#Draw the disorder hits
	foreach my $disorder (@{$protein_details{$protein}{'disorder'}}) {
		my $start = $disorder->[0];
		my $end = $disorder->[1];
		my $predictor = $disorder->[2];
        next if $predictor_details{$predictor}{include} eq 0;
        my $colour = $predictor_details{$predictor}{'colour'}; 
        my $name = $predictor_details{$predictor}{'name'}; 
        my $disporder = $predictor_details{$predictor}{'display_order'}; 
		my $y = $middle;
        #$y += ($predictor_details{$predictor}{'name'} eq "VLXT")?-($disorder_height+1):1;
        $y -= int($disporder) * ($disorder_height);
		my $width = 1 + $end - $start;

		$result .= <<EOF
	<rect x="$start" y="$y" width="$width" height="$disorder_height" style="fill: url(#disorder); stroke:none; stroke-width:0.0">
	</rect>
	<rect x="$start" y="$y" width="$width" height="$disorder_height" style="opacity: 0.5; fill: #$colour; stroke:#000; stroke-width:0.5" onmouseover="show_tip(evt)" onmouseout="hide_tip(evt)">
		<name>$name Predicted Disorder</name>
		<desc>Length: $width</desc>
		<range>Range: $start-$end</range>
</rect>
EOF
		;

	}
    
    #Draw the side labels for each disorder predictor, only shown with the key
    if ($draw_key) {
    foreach my $predictor (grep {$predictor_details{$_}{'type'} eq 'disorder' and $predictor_details{$_}{include} eq 1 } keys %predictor_details) {
        my $name = $predictor_details{$predictor}{'name'};
        my $disporder = $predictor_details{$predictor}{'display_order'}; 
        my $text_y = $disorder_height + $middle - (int($disporder) * ($disorder_height))-1;
        my $text_x = $protein_details{$protein}{'length'} + 20;
        $result .= "<text font-family='arial' font-size='$disorder_height' x='$text_x' y='$text_y'>$name</text>\n";
    }
}

    if ($draw_experiments) {
	    my $y = $dy+$disorder_spacing;
        foreach my $db (keys %{$experiments{$protein}}) {
           foreach my $db_id (keys %{$experiments{$protein}{$db}}) {
                $y += $disorder_height;
                foreach my $region (@{$experiments{$protein}{$db}{$db_id}}) {
                    my ($start,$end,$up_id,$classification,$external_link) = @$region;
                    my $colour = 'rgb(68,459,68)' if $classification eq 'disordered';
                    $colour = 'rgb(68,166,459)' if $classification eq 'ordered';
                    $classification = ucfirst $classification;
                    my $width = 1 + $end - $start;
		            $result .= <<EOF
    <a xlink:href="$external_link" xlink:show="new" target="_blank">
	<rect x="$start" y="$y" width="$width" height="$disorder_height" style="fill: url(#disorder); stroke:none; stroke-width:0.0">
	</rect>
	<rect x="$start" y="$y" width="$width" height="$disorder_height" style="opacity: 0.5; fill:$colour; stroke:#000; stroke-width:0.5" onmouseover="show_tip(evt)" onmouseout="hide_tip(evt)">
		<name>$db $db_id $classification</name>
		<desc>Length: $width</desc>
		<range>Range: $start-$end</range>
		<quality>UniProt: $up_id</quality>
    </rect>
    </a>
EOF
		            ;
                }
            }
            my $text_y = $y + $disorder_height-1;
            my $text_x = $protein_details{$protein}{'length'} + 20;
            $result .= "<text font-family='Arial' font-size='$disorder_height' x='$text_x' y='$text_y'>$db</text>\n";
        }
    }

	return $result;
}

=item B<draw_consensus($protein)>

	Draw all the disorder hits for a protein
=cut
sub draw_consensus {
	my ($protein) = @_;
    return unless defined $protein_details{$protein}{'consensus'};
	my $result = '';
	my $middle = $dy + ($record_height / 2);
    my $y = $middle + (2 * $weak_below) + $structure_height + $disorder_height + 5; 
	
    my $num_predictors = scalar grep {$predictor_details{$_}{type} eq 'disorder' } keys %predictor_details;

	#Draw the consensus strip
	foreach my $dx (0..@{$protein_details{$protein}{'consensus'}}-1) {
        next if $protein_details{$protein}{'consensus'}[$dx] == 0;
        next if $draw_conflicts and $protein_details{$protein}{'conflict'}[$dx] > 0;
        my $value;
        $value = $num_predictors / $protein_details{$protein}{'consensus'}[$dx];
        my ($r,$g,$b) = @{hsv2rgb(120.0,0.85,$value)};
		$result .= <<EOF
	<rect x="$dx" y="$y" width="1" height="$disorder_height" style="fill: rgb($r,$g,$b); stroke:none; stroke-width:0.0"></rect>
EOF
		;

	}
    $result .= "<text x=\"0\" y=\"".($y-2)."\" font-size=\"10\" font-family=\"Arial\">Predicted Disorder Agreement</text>";
	return $result;
}

=item B<draw_conflicts($protein)>

	Draw all the disorder hits for a protein
=cut
sub draw_conflicts {
	my ($protein) = @_;
    return unless defined $protein_details{$protein}{'conflict'};
	my $result = '';
	my $middle = $dy + ($record_height / 2) + $disorder_height + 5;
    my $y = $middle + (2*$weak_below) + $structure_height; 
	

	#Draw the consensus strip
	foreach my $dx (0..@{$protein_details{$protein}{'conflict'}}-1) {
        next if $protein_details{$protein}{'conflict'}[$dx] == 0;
        my $value;
        $value = $num_predictors / $protein_details{$protein}{'conflict'}[$dx];
        my ($r,$g,$b) = @{hsv2rgb(225.0,0.85,$value)};
		$result .= <<EOF
	<rect x="$dx" y="$y" width="1" height="$disorder_height" style="fill: rgb($r,$g,$b); stroke:none; stroke-width:0.0"></rect>
EOF
		;

	}
	$result .= "<rect x=\"0\" y=\"".($y)."\" width=\"$protein_details{$protein}{length}\" height=\"".($disorder_height)."\" style=\"fill: none; stroke:black; stroke-width:0.5;\"></rect>";
	return $result;
}

=item B<draw_structures($protein, $is_weak)>

	Draw all the structural hits for a protein, below the amino line if they are weak
=cut
sub draw_structures {
	my ($protein, $is_weak) = @_;
	my @structures;
	my $result = '';
	
	if ($is_weak) {
		@structures = @{$protein_details{$protein}{'structures'}{'weak'}};
	} else {
		@structures = @{$protein_details{$protein}{'structures'}{'strong'}};
	}
	
	foreach my $structure (@structures) {
	my @ranges = map {[split /-/, $_]} split /,/, $structure->[1];
	my $range = $structure->[1];
	my ($start, $end) = ($ranges[0][0],$ranges[0][1]);
	my $evalue = $structure->[2];
	my $link = "http://supfam.org/SUPERFAMILY/cgi-bin/scop.cgi?sunid=".$structure->[0];
	my $name = $structure->[3];
	$name .= ($is_weak)?$weak_note:'';
	my $fill = $sf_details{$structure->[0]}{'colour'};
	$start--;
	my $width = $end - $start;
	my $middle = $dy + ($record_height / 2);
	
	#Horizontally place the text box/callout
	my $tx = $start + ($end - $start)/2;
	
	#Vertically place the structure box
	my $y = $middle;
	$y += ($is_weak)?$weak_below:0; #Deal with weaker hits below the line stronger around the amino line
	$y -= $structure_height/2;
	
	my $drop_middle = $y + ($structure_height/2);
	
	#Vertically place the structure text box/callout
	my $ty = $y + $structure_height + 12;
	
	#Setup the callout arrow boxes
	my $label = $sf_details{$structure->[0]}{'label'};
	my $callout = ($draw_callouts)?callout($tx,$ty - 14,$label):'';
	$label = ($draw_labels)?"<text x=\"$tx\" y=\"$ty\" text-anchor=\"middle\" style=\"font-size:10px\">".$label."</text>":'';
				
	$result .= <<EOF
	<g>
EOF
;
	#Draw all of the blocks of structure for this hit, usually this is one but it can be more for inserted domains
	foreach my $part (@ranges) {
		($start, $end) = @{$part};
		$start--;
		$width = $end - $start;
		
		#Print drop down lines if this is a weaker hit
		if ($is_weak) {
			$result .= <<EOF
		<line x1="$start" y1="$middle" x2="$start" y2="$drop_middle" 
		   style="fill: none; stroke-dasharray:1,1; stroke: #000; stroke-width:1" />
		<line x1="$end" y1="$middle" x2="$end" y2="$drop_middle" 
		   style="fill: none; stroke-dasharray:1,1; stroke: #000; stroke-width:1" />
EOF
			;
		}
		
		#Print the structure box
		$result .= <<EOF
		<a xlink:href="$link" xlink:show="new" target="_blank">

			<rect x="$start" y="$y" width="$width" height="$structure_height" style="fill:$fill; opacity: 0.9;" rx="2" ry="2" onmouseover="show_tip(evt)" onmouseout="hide_tip(evt)">
				<name>$name</name>
				<desc>Length: $width</desc>
				<range>Range: $range</range>
				<quality>E-value: $evalue</quality>
			</rect>
			$callout
			$label
		</a>
EOF
		;
	}
	
	#Draw any connectors for inserted domain hits if we need to
	my @connector_ranges = map {split /-/, $_} split /,/, $structure->[1];
	shift @connector_ranges;
	pop @connector_ranges;
	while (my @connector = splice(@connector_ranges, 0, 2)) {
		my ($x1, $x2) = @connector;
		if ($is_weak) {
			$result .= <<EOF
			<line x1="$x1" y1="$drop_middle" x2="$x2" y2="$drop_middle" style="stroke:$fill; opacity: 0.9; stroke-width:2" />
EOF
			;
		}
		else {
			$result .= <<EOF
			<line x1="$x1" y1="$middle" x2="$x2" y2="$middle" style="stroke:$fill; opacity: 0.9; stroke-width:2" />
EOF
			;
		}
	}
	
	
	$result .= <<EOF
	</g>
EOF
	;

	}
	return $result;
}

=item B<draw_binding($proten)>

    Draws all binding regions
=cut
sub draw_binding {
    my ($protein) = @_;
	$dy = ($current_record * $record_height) + ($current_record * $record_spacing);
    my $top = $dy;
    my $middle = $dy + ($record_height / 2);
    my $bottom = $dy + $record_height;
    my $y = $middle + ($middle-$top)/2 +10;
    my $result = "<g>\n";
    foreach my $range (@{$protein_details{$protein}{'binding'}}) {
        my $start = $range->[0];
        my $width = 1 + $range->[1] - $start;
            $result .= "<rect x='$start' y='$y' width='$width' height='$binding_height' fill='gold' />\n";
            $result .= "<rect x='$start' y='$y' width='$width' height='$binding_height' fill='url(#binding)' opacity='0.5' onmouseover='show_tip(evt)' onmouseout='hide_tip(evt)'>\n";
		    $result .= "<name>ANCHOR binding region</name>";
    		$result .= "<range>Range: $range->[0]-$range->[1]</range>";
    		$result .= "<desc>Length: $width</desc>";
            $result .= "</rect>\n";
    }
    $result .= "</g>\n";
    return $result;
}
=item B<draw_ptms($proten)>

    Draws all non synonymous PTMs for this protein
=cut
sub draw_ptms {
    my ($protein) = @_;
	$dy = ($current_record * $record_height) + ($current_record * $record_spacing);
    my $top = $dy;
    my $middle = $dy + ($record_height / 2);
    my $bottom = $dy + $record_height - 5;
    my $result = "<g>\n";
    my $count = 0;
    foreach my $ptm (@{$ptm_details{$protein}}) {
        #Alternate heights and dashing of PTMs that are near each other
        my $label = $ptm_abrev{$ptm->{'type'}};
        my $displace = $bottom-$ptm_size*($count%$ptm_levels);
        my $dashstop1 = 1+$count%8;
        my $dashstop2 = 1+$count%5;
        $count++;
        $result .= "<line x1='$ptm->{'locus'}' y1='$displace' x2='$ptm->{'locus'}' y2='$middle' style='stroke:black;stroke-width:0.25; stroke-dasharray: $dashstop1,$dashstop2;' />\n";
        my $txt_x = $ptm->{'locus'}-2*($ptm_size/6);
        my $txt_y = $displace+$ptm_size;
        my $dot_y = $displace+2*($ptm_size/3);
        my $dot_size = $ptm_size / 2;
        $result .= "<circle cx='$ptm->{'locus'}' cy='$dot_y' r='$dot_size' fill='$ptm_colours{$ptm->{'type'}}'/>";
        $result .= "<circle cx='$ptm->{'locus'}' cy='$dot_y' r='$dot_size' opacity='1.0' fill='url(#radial-glow)' />";
        if ($ptm->{'disordered'}) {
            $result .= "<text font-family='arial' font-size='$ptm_size' style='fill:white' x='$txt_x' y='$txt_y'>$label</text>\n";
            $result .= "<text font-family='arial' font-size='$ptm_size' style='filter:url(#emboss);' x='$txt_x' y='$txt_y'>$label</text>\n";
        } else {
            $result .= "<text font-family='arial' font-size='$ptm_size' style='fill:white' x='$txt_x' y='$txt_y'>$label</text>\n";
            $result .= "<text font-family='arial' font-size='$ptm_size' style='filter:url(#emboss);' x='$txt_x' y='$txt_y'>$label</text>\n";
        }
        $result .= "<circle cx='$ptm->{'locus'}' cy='$dot_y' r='$dot_size' opacity='0.0' onmouseover='show_tip(evt)' onmouseout='hide_tip(evt)'>";
        my $name = $ptm->{'type'}; 
        $name =~ s/_/ /g;
        $name =~ s/(\w+)/\u\L$1/g;
        my $region = $ptm->{'seq'};
        substr($region,7,1,"[".substr($region,7,1)."]");
        $region =~ s/_//g;
		$result .= "<name>$name site</name>";
		$result .= "<range>Locus: $ptm->{'locus'}</range>";
		$result .= "<quality>Modifying: $ptm->{'amino'}</quality>";
		$result .= "<desc>Region: $region</desc>";
        $result .= "</circle>";

    }
    $result .= "</g>\n";
    return $result;
}

=item B<draw_protein($protein)>

	Draws the amino line and labels for a protein, delegates to draw_disorder and draw_structures for the protein assignments.
=cut
sub draw_protein {
	my ($protein) = @_;
	my $length = $protein_details{$protein}{'length'};
	$ruler_width = $length if $length > $ruler_width;
	my $names = $protein_details{$protein}{'names'};
	my @names;
	my $result = "<g>\n";

	$dy = ($current_record * $record_height) + ($current_record * $record_spacing);
	my $y = $dy + 10;
	my $top = $dy;
	my $middle = $dy + ($record_height / 2);
	my $bottom = $dy + $record_height;

	#Draw the protein labels
	foreach my $seqid (@$names) {
        if ($force_png) {
            push @names, "$seqid->[1]";
        } else {
		    push @names, '<a xlink:show="new" target="_blank" xlink:href="http://supfam.org/SUPERFAMILY/cgi-bin/gene.cgi?genome='.$seqid->[0].';seqid='.$seqid->[1].'">'.$seqid->[1].'</a>';
        }
	}
	my $name = join ', ', @names;
	$result .= "<text x=\"0\" y=\"$y\" font-family=\"Arial\" font-size=\"10\">$name</text>";
	
	#Draw protein amino line
	$y = $middle -1;
	$result .= <<EOF
	  <rect x="0" y="$y" width="$length" height="2" rx="0" ry="0"
	     style="fill: #333;" />
EOF
	;
	$result .= draw_disorder($protein) if ($draw_disorder);
    $result .= draw_consensus($protein) if ($draw_disorder and $draw_consensus); 
    $result .= draw_conflicts($protein) if ($draw_disorder and $draw_conflicts); 

    unless ($nostruct) {
    	$result .= draw_structures($protein);
	    $result .= draw_structures($protein, 'weaker') if $include_weak_hits;
    }
    
    if ($draw_key) {
        if ($draw_experiments and $protein_details{$protein}{'num_experiments'} >= 1) {
            my $num_experiments = $protein_details{$protein}{'num_experiments'};
            my $brace_y = $top+$disorder_spacing+$disorder_height;
            my $text_y = $brace_y + 2.5 + $num_experiments/2*$disorder_height;
            my $text_x = $length+20;
            my $brace_height = $num_experiments*$disorder_height;
            $result .= "<g transform='translate($length,$brace_y)'>\n
                            <svg preserveAspectRatio='none' viewBox='0 0 60 160' width='30' height='$brace_height' version='1.1' xmlns='http://www.w3.org/2000/svg'>\n
                                <path stroke='black' stroke-width='1.0' fill='none' 
                                    d='m 0,0 
                                        c 7,0 11,1 13,3 3,3 4,4 4,7 
                                        l 0,25 
                                        c 0,15 2,25 5,31 3,6 9,10 15,13 -6,3 -12,7 -15,13 -3,6 -5,16 -5,31 l 0,25 
                                        c 0,3 -1,4 -4,7 -2,2 -6,3 -13,3' />\n
                            </svg>\n
                        </g>";
                #$result .= "<text font-size='10' x='$text_x' y='$text_y'>Verified Disorder</text>";
        }
        if ($draw_disorder) {
            my $brace_y = $middle-$disorder_spacing-$num_predictors*$disorder_height;
            my $text_y = $brace_y + 2.5 + $num_predictors/2*$disorder_height;
            my $text_x = $length+20;
            my $brace_height = $num_predictors*$disorder_height;
            $result .= "<g transform='translate($length,$brace_y)'>\n
                            <svg preserveAspectRatio='none' viewBox='0 0 60 160' width='30' height='$brace_height' version='1.1' xmlns='http://www.w3.org/2000/svg'>\n
                                <path stroke='black' stroke-width='1.0' fill='none' 
                                    d='m 0,0 
                                        c 7,0 11,1 13,3 3,3 4,4 4,7 
                                        l 0,25 
                                        c 0,15 2,25 5,31 3,6 9,10 15,13 -6,3 -12,7 -15,13 -3,6 -5,16 -5,31 l 0,25 
                                        c 0,3 -1,4 -4,7 -2,2 -6,3 -13,3' />\n
                            </svg>\n
                        </g>";
                #$result .= "<text font-size='10' x='$text_x' y='$text_y'>Predicted Disorder</text>";
        }
        unless ($nostruct) {
            my $brace_y = $middle - $structure_height;
            my $brace_height = 10+$structure_height*2;
            $brace_height += $weak_below if $include_weak_hits; 
            my $text_y = $brace_y + $brace_height/2 + 3;
            my $text_x = $length+20;
            $result .= "<g transform='translate($length,$brace_y)'>\n
                            <svg preserveAspectRatio='none' viewBox='0 0 60 160' width='30' height='$brace_height' version='1.1' xmlns='http://www.w3.org/2000/svg'>\n
                                <path stroke='black' stroke-width='1.0' fill='none' 
                                    d='m 0,0 
                                        c 7,0 11,1 13,3 3,3 4,4 4,7 
                                        l 0,25 
                                        c 0,15 2,25 5,31 3,6 9,10 15,13 -6,3 -12,7 -15,13 -3,6 -5,16 -5,31 l 0,25 
                                        c 0,3 -1,4 -4,7 -2,2 -6,3 -13,3' />\n
                            </svg>\n
                        </g>";
                $result .= "<text font-size='10' x='$text_x' y='$text_y'>Predicted Domains</text>";
        }
        if ($draw_binding) {
            my $brace_y = $middle + ($middle-$top)/2+$binding_height;
            my $brace_height = $binding_height*3;
            my $text_y = $brace_y + $brace_height/2 + 3;
            my $text_x = $length+20;
            $result .= "<g transform='translate($length,$brace_y)'>\n
                            <svg preserveAspectRatio='none' viewBox='0 0 60 160' width='30' height='$brace_height' version='1.1' xmlns='http://www.w3.org/2000/svg'>\n
                                <path stroke='black' stroke-width='1.0' fill='none' 
                                    d='m 0,0 
                                        c 7,0 11,1 13,3 3,3 4,4 4,7 
                                        l 0,25 
                                        c 0,15 2,25 5,31 3,6 9,10 15,13 -6,3 -12,7 -15,13 -3,6 -5,16 -5,31 l 0,25 
                                        c 0,3 -1,4 -4,7 -2,2 -6,3 -13,3' />\n
                            </svg>\n
                        </g>";
                $result .= "<text font-size='10' x='$text_x' y='$text_y'>Binding Regions</text>";
        }
        if ($draw_ptms) {
            my $brace_y = 5+$bottom - $ptm_size*$ptm_levels;
            my $brace_height = $ptm_size*$ptm_levels;
            my $text_y = $brace_y + $brace_height/2 + 3;
            my $text_x = $length+20;
            $result .= "<g transform='translate($length,$brace_y)'>\n
                            <svg preserveAspectRatio='none' viewBox='0 0 60 160' width='30' height='$brace_height' version='1.1' xmlns='http://www.w3.org/2000/svg'>\n
                                <path stroke='black' stroke-width='1.0' fill='none' 
                                    d='m 0,0 
                                        c 7,0 11,1 13,3 3,3 4,4 4,7 
                                        l 0,25 
                                        c 0,15 2,25 5,31 3,6 9,10 15,13 -6,3 -12,7 -15,13 -3,6 -5,16 -5,31 l 0,25 
                                        c 0,3 -1,4 -4,7 -2,2 -6,3 -13,3' />\n
                            </svg>\n
                        </g>";
                $result .= "<text font-size='10' x='$text_x' y='$text_y'>PTM Sites</text>";
        }
    }

	return $result."\n</g>\n";
}

=item B<amino_ruler>

	Draw a ruler showing to the longest length amino line drawn by draw_protein (this is stored in the $ruler_width global variable).
	50 amino acid intervals are demarked with the last tick being the max length value.
=cut
sub amino_ruler {
	my $num_ticks = floor($ruler_width/50);
	my $tick_interval = floor( ($ruler_width/$num_ticks) / 10 ) * 10;
	

	my $result = <<EOF
		  <line x1="0" y1="$dy" x2="$ruler_width" y2="$dy" style="stroke: #333; stroke-width: 1;" />
EOF
		;
	foreach my $tick ( range(0,$ruler_width,$tick_interval) ) {
		my $y = $dy + 3;
		$result .= "	  <line x1=\"$tick\" y1=\"$dy\" x2=\"$tick\" y2=\"$y\" style=\"stroke: #333; stroke-width: 0.5;\" />";
		$y += 10;
		$result .= "	  <text x=\"$tick\" y=\"$y\" text-anchor=\"middle\" style=\"font-size:10px\">$tick</text>";
	}

	if ($ruler_width % $tick_interval > $tick_interval/2) {
		my $y = $dy + 3;
		$result .= "	  <line x1=\"$ruler_width\" y1=\"$dy\" x2=\"$ruler_width\" y2=\"$y\" style=\"stroke: #333; stroke-width: 0.5;\" />";
		$y += 10;
		$result .= "	  <text x=\"$ruler_width\" y=\"$y\" text-anchor=\"middle\" style=\"font-size:10px\">$ruler_width</text>";
	}
	return $result;
}

=item B<sf_key>

	Draw the key for the superfamilies found in the input set of proteins indexed with both colours and numbers.
=cut
sub sf_key {
	my $top = $dy;
	my $text_dy;
	my $result = '';
    my $dx = 0; 
    
	my $is_weak_hits = 0;
    unless ($nostruct) {
	foreach my $protein (keys %protein_details) {
		$is_weak_hits = 1 if defined $protein_details{$protein}{'structures'}{'weak'};
		last if $is_weak_hits;
	}
    }

	$result = "<text x=\"$dx\" y=\"$dy\" font-size=\"12\">Key:</text>";
	$dy += 5;
	$dx += 5;
	$text_dy = $dy + 8;
    
    unless ($nostruct) {
        #Annotate predicted structure block
        $result .= "<rect x=\"$dx\" y=\"$dy\" width=\"10\" height=\"10\" fill=\"#ccc\" ry=\"2\" rx=\"2\" />";
        $result .= "<text x=\"".($dx+12)."\" y=\"$text_dy\" font-size=\"10\">Predicted Structure</text>";
        $dy+=12;
        $text_dy = $dy + 8;

        #Annotate that weak hits are dropped down	
        if ($is_weak_hits) {
            my $y = $dy + 10;
            $result .= "<line x1=\"".($dx+5)."\" y1=\"$dy\" x2=\"".($dx+5)."\" y2=\"$y\" style=\"fill:none;stroke-dasharray:1,1;stroke:#000;stroke-width:1\"/>";
            $result .= "<text x=\"".($dx+12)."\" y=\"$text_dy\" font-size=\"10\">Weak Structural Hit</text>";
            $dy+=12;
            $text_dy = $dy + 8;	
        }
    }
	#Add disorder block to the key if we are including those results
	if ($draw_disorder) {
		$result .= "<rect x=\"$dx\" y=\"$dy\" width=\"10\" height=\"10\" fill=\"url(#disorder)\" stroke=\"#000\" stroke-width=\"0.5\" />";
		$result .= "<text x=\"".($dx+12)."\" y=\"$text_dy\" font-size=\"10\">Predicted Disorder</text>";
		$dy+=12;
		$text_dy = $dy + 8;
	}
    if ($draw_binding) {
		$result .= "<rect x=\"$dx\" y=\"".($dy+3)."\" width=\"10\" height=\"5\" fill=\"url(#binding)\" />";
		$result .= "<text x=\"".($dx+12)."\" y=\"$text_dy\" font-size=\"10\">Predicted Binding Region</text>";
		$dy+=12;
		$text_dy = $dy + 8;
    }
    #Add PTM sites to the key if we are including those results
    if ($draw_ptms) {
        $dx += 5;
        $dy += 5;
        $result .= "<circle cx='$dx' cy='$dy' r='5' fill='#666666'/>";
        $result .= "<circle cx='$dx' cy='$dy' r='5' opacity='1.0' fill='url(#radial-glow)' />";
        $dy += 3; 
        $dx -= 2; 
        $result .= "<text font-family='arial' font-size='8' style='fill:white' x='$dx' y='$dy'>?</text>\n";
        $result .= "<text font-family='arial' font-size='8' style='filter:url(#emboss);' x='$dx' y='$dy'>?</text>\n";
		$result .= "<text x=\"".($dx+9)."\" y=\"$text_dy\" font-size=\"10\">Curated PTM Site</text>";
    }

	$dy = $top;
    $dx = 150;
    
    #Draw the disorder predictor key
	if ($draw_disorder) {

	$result .= "<text x=\"$dx\" y=\"$dy\" font-size=\"12\">Predictors:</text>";
	$dy += 5;
	$dx += 5;
	$text_dy = $dy + 8;

	foreach my $predictor (sort {$predictor_details{$b}{display_order} <=> $predictor_details{$a}{display_order}} grep {$predictor_details{$_}{type} eq 'disorder' and $predictor_details{$_}{include} eq 1 } keys %predictor_details) {
		my $colour = $predictor_details{$predictor}{'colour'};
		my $name = $predictor_details{$predictor}{'name'};
		my $label = $predictor;
		my $key = $name;
	    $result .= "<rect x=\"$dx\" y=\"$dy\" width=\"10\" height=\"10\" style=\"fill: url(#disorder); stroke:none; stroke-width:0.0\" />\n";
        $result .= "<rect x=\"$dx\" y=\"$dy\" width=\"10\" height=\"10\" style=\"opacity: 0.5; fill: #$colour; stroke:#000; stroke-width:0.5;\" />\n";
		$result .= "<text x=\"".($dx+12)."\" y=\"$text_dy\" font-size=\"10\">$key</text>";
		$dy+=12;
		$text_dy = $dy + 8;
	}
    $dy = $top;
    $dx += 100;
    }

    #Draw the superfamily labels key
    unless ($nostruct) {
        $result .= "<text x=\"$dx\" y=\"$dy\" font-size=\"12\">Superfamilies:</text>";
        $dy += 5;
        $dx += 5;
        $text_dy = $dy + 8;

        foreach my $sf (sort {$sf_details{$a}{'label'} <=> $sf_details{$b}{'label'}} keys %sf_details) {
            my $colour = $sf_details{$sf}{'colour'};
            my $name = $sf_details{$sf}{'description'};
            my $label = $sf_details{$sf}{'label'};
            my $key = ($draw_labels and not $supfam_labels)?"[$label] $name":"$name";
            $result .= "<rect x=\"$dx\" y=\"$dy\" width=\"10\" height=\"10\" fill=\"$colour\" stroke=\"black\" stroke-width=\"0.5\" />";
            $result .= "<text x=\"".($dx+12)."\" y=\"$text_dy\" font-size=\"10\">$key</text>";
            $dy+=12;
            $text_dy = $dy + 8;
        }
        if (scalar keys %sf_details == 0) {
            $result .= "<text x=\"$dx\" y=\"$text_dy\" font-size=\"10\">N/A No Hits</text>";
        }
    }
	#Makesure we have a height that covers the Key section
	$dy = $top + 50 if $dy < ($top + 50);
	return $result;
}

#Get protein and sf details from the database
get_details();

#Foreach protein draw the entry and then iterate the vertical cursor to the next record
foreach my $protein (keys %protein_details) {
    $output .= draw_ptms($protein) if $draw_ptms;
	$output .= draw_protein($protein);
    $output .= draw_binding($protein) if $draw_binding;
	$current_record++;
	$dy += $record_height;
} #Protein foreach

#Print out amino ruler
if ($draw_ruler) {
	$dy += $record_spacing; #after some vertical white space
	$output .= amino_ruler();
	$dy += 20;
}

#Print out the figure key
$dy += $record_spacing; #after some vertical white space
$output .= sf_key() if $draw_key;

#Print out the SVG footer containing the tooltip popup markup/design
$output .= footer();

#Print out SVG and ECMA script popup header
my $width = $ruler_width + ($xpad*3);
$width = $min_width if $width < $min_width and $draw_labels;
$width += $key_size;
my $height = $dy + ($record_height*0.3);
$output = header($width,$height) . $output;

if ($force_png) {
	use File::Temp qw/tempfile/;
	my ($fh,$filename) = tempfile( 'architectureXXXXXX', UNLINK => 1, TMPDIR => 1, SUFFIX => '.svg' );
	print $fh $output;
    if ($download) {
        print $cgi->header(-type => "image/png", -attachment => "Protein_disorder.png");
    } else {
	    print $cgi->header(-type => "image/png");
    }
    #Using ImageMagick to convert to PNG
	#open (PNG, '|-', "convert -background None -size ${width}x${height} svg:$filename --compress None --depth 32 png:fd:1") or error("Couldn't convert to PNG.");

    #Using RSVGlib directly, much nicer results!
    #If we want print quality up the DPI and pixel content
    if ($forprint) {
        $width *= $scale * 2;
        $height *= $scale * 2;
	    open (PNG, '|-', "rsvg -d 300 -p 300 --format=png -w ${width} -h ${height} $filename /dev/stdout") or error("Couldn't convert to PNG.");
    } else {
        $width *= $scale;
        $height *= $scale;
	    open (PNG, '|-', "rsvg --format=png -w ${width} -h ${height} $filename /dev/stdout") or error("Couldn't convert to PNG.");
    }
	print <PNG>;
	close(PNG) or error("Failed to close pipe.");
}
else {
    if ($download) {
        print $cgi->header(-type => "image/svg+xml", -attachment => "Protein_disorder.svg");
    } else {
    	print $cgi->header(-type => "image/svg+xml");
    }
	print $output;
}

=back
=cut

1;
