package DisDB;
use Mojo::Base 'Mojolicious';
use Mojo::UserAgent;
use Data::Dumper;

use DisDB::Utils::Config;

# This method will run once at server start
sub startup {
    my $self = shift;

    #Deal with PROXY
    $ENV{MOJO_REVERSE_PROXY} = 1;
    $self->hook('before_dispatch' => sub {
        #my $self = shift;
        
        #if ($self->req->headers->header('X-Forwarded-Host')) {
            ### Proxy Path setting ###
            ### Don't need this atm since Apache is setting the correct stuff for Mojolicious to see
            #my $path = '/disorder';
            
            #$self->req->url->base->path->parse($path);
        #}

    });

    $self->plugin('DisDB::Plugin::TemplateRewrite');

    my $ua = Mojo::UserAgent->new;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

    $self->config(hypnotoad => {listen => ['http://localhost:3000'], workers => 4, proxy => 1});


    # Login to Facebook
    $self->plugin('o_auth2',
          facebook => {
                key => '',
                secret => '',
                redirect_uri => 'http://localhost:3000/auth/login'
           });

    
    #### ROUTES
    
    # Home and Auth
    my $r = $self->routes;
    $r->route('/')->to('main#frontpage');
    $r->route('/contact')->to('main#contact');
    $r->route('/auth/logout')->to('auth#logout');
    $r->route('/auth/login')->to('auth#login');

    #Download
    $r->route('/download')->to('main#download');

    #Feedback

    $r->route('/feedback')->to(controller => 'main', action => 'feedback');
    $r->route('/feedback/post')->to(controller => 'main', action => 'post_feedback');
   
    #About

    $r->route('/about')->to(controller => 'about', action => 'about');
    $r->route('/about/database')->to(controller => 'about', action => 'database');
    $r->route('/about/genomes')->to(controller => 'about', action => 'genomes');
    $r->route('/about/predictors')->to(controller => 'about', action => 'predictors');

    # Auto Complete
    $r->route('/complete/genome')->to('complete#genome'); 

    # Search
    $r->route('/search')->to(controller => 'search', action => 'search'); 
    $r->route('/search/blast')->to(controller => 'search', action => 'by_blast');
    $r->route('/search/sequence')->to(controller => 'search', action => 'by_sequence');
    $r->route('/search/seqid')->to(controller => 'search', action => 'by_seqid');
    $r->route('/search/superfamily/:sf')->to(controller => 'search', action => 'by_sf');
    $r->route('/search/build')->to(controller => 'search', action => 'build');
    $r->route('/search/build/new')->to(controller => 'search', action => 'build_new');
    $r->route('/clear/:constraint')->to(controller => 'search', action => 'build_clear');
    $r->route('/add/:constraint/:value')->to(controller => 'search', action => 'add_build_constraint');

    # Proteins
    $r->route('/protein/info/:protein')->to(controller => 'protein', action => 'info');
        
    # Predictors
    $r->route('/about/predictors')->to(controller => 'predictor', action => 'info');
    $r->route('/predictor/info/:predictor')->to(controller => 'predictor', action => 'details');

    # Figure data
    $r->route('/figure/predictor_percent_coverage/:predictor')->to(controller=>'figure', action=>'predictor_percent_coverage');
}

1;
