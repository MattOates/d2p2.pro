package DisDB::Auth;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::UserAgent;

use Data::Dumper;

my $ua = Mojo::UserAgent->new;

# This action will log a user into the site via facebook OAuth2 and then store the credentials in the session
sub login {
	my $self = shift;
	my $session = $self->session;

    #If we are already logged in don't attempt to login again
	unless ($session->{'uid'}) {

        #Do some FB authentication using the OAuth2 plugin
		$self->get_token('facebook',
            #Request that facebook returns the users email address along with everything else.
            scope => 'email', 
            #Handle a successful auth request
            callback => sub {
                my $token = shift;
                my $user = $ua->get('https://graph.facebook.com/me?access_token='.$token)->res->json;
                $session->{'user_id'} = $user->{'id'};
                $session->{'user_email'} = $user->{'email'};
                $session->{'user_name'} = $user->{'username'};
                $session->{'first_name'} = $user->{'first_name'};
                $session->{'last_name'} = $user->{'last_name'};
                $self->render();
            },
            #Handle a failed request
            error_handler => sub {
                my $request = shift->req;
                $self->render(text => 'Erk problems!<br />'.$request->url);
            },
        );
	} else {
		$self->render(text => "You already logged in ".$session->{'first_name'});
	}
}

# Remove the current session
sub logout {
	my $self = shift;

	$self->session(expires => 1);
    $self->redirect_to('/disorder/');

}

1;
