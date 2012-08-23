package DisDB::About;
use Mojo::Base 'Mojolicious::Controller';

use DisDB::Utils::Config;

sub about {
	my $self = shift;
	$self->render();
}

sub predictors {
	my $self = shift;

    use DisDB::SQL::Predictor qw'getPredictors getPredictorPeople';
    $self->stash(disorder_predictors => getPredictors('disorder'));
    $self->stash(structure_predictors => getPredictors('structure'));
    $self->stash(people => getPredictorPeople());
    
	$self->render();
}

sub database {
	my $self = shift;
	$self->render();
}

sub genomes {
	my $self = shift;
	$self->render();
}

1;
