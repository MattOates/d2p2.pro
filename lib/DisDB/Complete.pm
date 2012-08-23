package DisDB::Complete;
use Mojo::Base 'Mojolicious::Controller';

use DisDB::SQL::Complete qw/completeGenomeName/;

sub genome {
    my $self = shift;
    my $query = $self->param('query');
    my $genomes = completeGenomeName($query);
    $self->render(json => $genomes);
}

1;
