package DisDB::Figure;
use Mojo::Base 'Mojolicious::Controller';

use DisDB::Utils::Config;
use DisDB::SQL::Figure qw/getPredictorPercentCoverage/;

# Render JSON for the predictor percent coverage histogram
sub predictor_percent_coverage {
	my $self = shift;
	my $predictor = $self->param('predictor');
    my $percent_coverage = getPredictorPercentCoverage($predictor);
    $self->render(json => $percent_coverage);
}

1;
