package DisDB::Protein;
use Mojo::Base 'Mojolicious::Controller';

use DisDB::Utils::Config;
use DisDB::SQL::Protein qw/getArchitectures/;

# This action will render a template
sub info {
	my $self = shift;
	my $pid = $self->param('pid');
    my $genome = $self->param('genome');
    my $comb = getArchitectures($pid);
	# Render template "example/welcome.html.ep" with message
	$self->render(pid => $pid, comb => $comb genome => $genome);
}

1;
