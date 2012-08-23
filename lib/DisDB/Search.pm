package DisDB::Search;
use Mojo::Base 'Mojolicious::Controller';

use DisDB::Utils::Config;
use DisDB::SQL::Search qw/getProteinBySeq getProteinBySeqID/;

# This action will render a template
sub search {
	my $self = shift;
	$self->render();
}

sub by_sequence {
    my $self = shift;
    my $sequence = $self->param('sequence');
    my $format = $self->param('format');
    my %formats = (
        fasta => "FASTA",
        tab => 'Tab-delimited (ID\tSequence\n)',
        abi => "ABI tracefile",
        ace => "Ace database",
        alf => "ALF tracefile",
        bsml => "BSML",
        chaos => "CHAOS sequence",
        ctf => "CTF tracefile",
        embl => "EMBL database",
        entrezgene => "Entrez Gene ASN1",
        exp => "Staden EXP",
        metafasta => "Meta FASTA",
        gcg => "GCG",
        genbank => "GenBank",
        kegg => "KEGG",
        lasergene => "Lasergene",
        locuslink => "LocusLink",
        phd => "Phred",
        pir => "PIR database",
        pln => "PLN tracefile",
        strider => "DNA Strider",
        swiss => "SwissProt",
        tigr => "TIGR XML",
        tinyseq => "NCBI TinySeq XML",
        ztr => "ZTR tracefile"
    );

    #Makesure the format requested is a valid format
    unless (exists $formats{$format}) {
        $self->stash(error => { sequence => {
            type => 'error',
            title => 'Sorry, sequence format not supported.',
            message => "No sequence formats matched $format.",
        }});
        $self->render(controller => 'search', action => 'search');
    }


    #The proteins we found for this request
    my %proteins;
    my $num_results = 0;

    #Use BioPerl SeqIO to parse the users query, block localises some horror handling exceptions internally
    {
        use Bio::SeqIO;
        #Use the query string as if it was a file
        use IO::String;
        my $seqfh = new IO::String($sequence);
        my $seqio;
        
        #This whole block is here to catch the BioPerl exceptions and wrap them into errors
        #returned back to the search form content.

        #Set the __DIE__ handler for this lexically scoped block to be our handler
        local $SIG{__DIE__} = sub {

            #If the exception is an Object of the type Bio::Root::Exception lets deal with it our way
            use Scalar::Util qw(blessed);
            if (blessed($@) && $@->isa("Bio::Root::Exception")) {
                    my $message = join ("<br />", grep (/MSG/, split (/\n/, $@)));
                    $message =~ s/MSG:\s+//;
                    $message =~ s/Not .* in my book\.?//;
                    #Put a message in the stash to be rendered in our form
                    $self->stash(error => { sequence => {
                        type => 'error',
                        title => "Not $formats{$format} formatted.",
                        message => $message
                    }});

                    #For some reason if we redirect Mojolicious catches our exception
                    #TODO swallow exception here so we can redirect ok. might just need to remove local from $@ below
                    #$self->redirect_to(controller => 'search', action=> 'search');

                    #Rendering the form again works fine
                    $self->render(controller => 'search', action => 'search');

            } else {
                CORE::die($@);
            }
        };

        local $@;
        eval {
           $seqio = new Bio::SeqIO(-fh => $seqfh, -format => $format);
        };
        if ($@) {
                    $self->render_text('search');
        }

        while( my $seq = $seqio->next_seq ) {
            if (exists $proteins{$seq->seq}) {
                push @{$proteins{$seq->seq}{ids}}, $seq->id;
            } else {
                my $results = getProteinBySeq(uc($seq->seq));
                if ($results) {
                    $proteins{$seq->seq} = { ids => [$seq->id], proteins => $results };
                    $num_results++;
                } else {
                    $proteins{$seq->seq} = { ids => [$seq->id], proteins => undef };
                }
            }
        }

    }

    unless ($num_results) {
        $self->stash(error => { sequence => {
            type => 'info',
            title => 'Sorry, no results found.',
            message => 'No sequences in the database matched those in your query set.',
        }});

        $self->render(controller => 'search', action => 'search');
    }

    $self->stash(proteins => \%proteins);
  	$self->render();
}

sub by_seqid {
	my $self = shift;
    #split on space delimits and ignore blanks
	my $seqid = [grep {/.+/} split /\s/, $self->param('seqid')];
    my $results = getProteinBySeqID($seqid);
    my $num_results = 0;
    if (ref $results eq 'HASH') {
        map {$num_results += defined $_} values %$results;
    }
    if ($results == undef or $num_results == 0) {
        $self->stash(error => { seqid => {
            type => 'info',
            title => 'Sorry, no results found.',
            message => 'No proteins found for your sequence IDs.',
        }});
        $self->render(controller => 'search', action => 'search');
    } else {
        $self->stash('proteins' => $results);
        $self->render();
    }
}

sub by_protein {

}

sub build {
    my $self = shift;
    $self->render();
}

1;
