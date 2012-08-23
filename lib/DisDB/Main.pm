package DisDB::Main;
use Mojo::Base 'Mojolicious::Controller';


# This action will render a template
sub frontpage {
  my $self = shift;

  # Render template "main/frontpage.html.ep"
  $self->render();
}

# This action will render a template
sub contact {
  my $self = shift;

  # Render template "main/frontpage.html.ep"
  $self->render();
}

sub download {
    my $self = shift;
    $self->render();
}

sub feedback {
    my $self = shift;
    $self->render();
}

sub post_feedback {
    my $self = shift;
    #TODO
    #Put feedback into the table here!
    $self->stash(name => $self->param('name'));
    $self->render();
}


1;
