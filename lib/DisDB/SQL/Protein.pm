#!/usr/bin/env perl
package DisDB::SQL::Protein;

use strict;
use warnings;

our $VERSION = '1.00';
use base 'Exporter';

use DisDB::Util::DBConnect;

our %EXPORT_TAGS = (
'all' => [ qw/
			getArchitectures
            getDisorder
            getStructure
            getPredictions
/ ],
'arch' => [ qw/
			getArchitectures
/ ]
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw//;

=item getArchitectures - Retrieve a list of comb strings for a given list or single protein id
 params: protein_id, optional DBI handle
 returns: A single comb string, or a hash of protein id mapped to combs
=cut
sub getArchitectures {
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

sub getDisorder {
    my ($proteins,$dbh) = @_;
    $dbh = dbConnect('disorder') unless defined $dbh;
    my $close_dbh = (@_ > 1)?1:0;
    
	my $sf_index = 1;
    $proteins = [$proteins] unless (ref $proteins eq 'ARRAY');
    my %disorder;

	foreach my $protein (@$proteins) {
		next if exists $disorder{$protein};
		
			my $disordered_hits = $dbh->selectall_arrayref("SELECT dis_assignment.start, dis_assignment.end, dis_assignment.predictor FROM $disorder_db.dis_assignment WHERE protein = ? ORDER BY start ASC", undef, $protein);
            $disorder{$protein} = {} if (scalar @$disordered_hits > 0);
			$protein_details{$protein}{'disorder'} = [];
			foreach (@$disordered_hits) {
				push @{$protein_details{$protein}{'disorder'}}, $_;
			}
            %predictor_details = %{$dbh->selectall_hashref("SELECT predictor, colour, has_probs, name, type, display_order FROM $disorder_db.predictor;", 'predictor')};
            
            if ($draw_consensus or $draw_conflicts) {
			    my ($cons, $conf) = $dbh->selectrow_array("SELECT consensus, conflict FROM $disorder_db.protein_consensus_conflict WHERE protein = ?", undef, $protein);
                if ($cons) {
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


sub getStructure {
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
			my $result = $dbh->selectall_arrayref("SELECT genome, seqid FROM $superfamily_db.protein WHERE protein = ? AND genome = ?", undef, $protein, $genome);
			$protein_details{$protein}{'names'} = $result;
		}
		else {
			my $result = $dbh->selectall_arrayref("SELECT genome, seqid FROM $superfamily_db.protein WHERE protein = ? ORDER BY genome DESC", undef, $protein);
			$protein_details{$protein}{'names'} = $result;
		}
		
		#Get all the disordered hits from the dis_assignment table
		if ($draw_disorder) {
			my $disordered_hits = $dbh->selectall_arrayref("SELECT dis_assignment.start, dis_assignment.end, dis_assignment.predictor FROM $disorder_db.dis_assignment WHERE protein = ? ORDER BY start ASC", undef, $protein);
			$protein_details{$protein}{'disorder'} = [];
			foreach (@$disordered_hits) {
				push @{$protein_details{$protein}{'disorder'}}, $_;
			}
            %predictor_details = %{$dbh->selectall_hashref("SELECT predictor, colour, has_probs, name, type, display_order FROM $disorder_db.predictor;", 'predictor')};
            
            if ($draw_consensus or $draw_conflicts) {
			    my ($cons, $conf) = $dbh->selectrow_array("SELECT consensus, conflict FROM $disorder_db.protein_consensus_conflict WHERE protein = ?", undef, $protein);
                if ($cons) {
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

sub getPredictions {
    my ($protein) = @_;
    if (ref $protein eq 'ARRAY') {
        my %proteins = map {$_ => undef}, @$protein;
        foreach my $protein_id (keys %proteins) {
            $proteins{$protein_id} =  {
                disorder => getDisorder($protein_id),
                structure => getStructure($protein_id)
            }
        }
        return \%proteins;
    } else {
        return { $protein => {
            disorder => getDisorder($protein),
            structure => getStructure($protein)
            }
        };
    }
}

1;
