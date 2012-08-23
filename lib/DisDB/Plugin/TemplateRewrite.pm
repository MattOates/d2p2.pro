package DisDB::Plugin::TemplateRewrite;
use Mojo::Base 'Mojolicious::Plugin';

use DisDB::Utils::Config;

#Register all of the helper functions for this plugin
sub register {
my ($self, $app) = @_;
    #Prefix URLs with the site prefix from the config, used when proxying with apache2
    $app->helper(
    url =>
        sub {
            my ($self, $url) = @_; 
            return config('webserver.prefix').$url;
        }
    );
    $app->helper(
    svg =>
        sub {
            my ($self, $url, $force_png) = @_;
            
            if ($force_png) {
                return qq|<img src="$url&png=1" alt="$url" />|;
            }

            #Parse the user agent string so that we get a floating point browser version
            use Parse::HTTP::UserAgent;
            my $ua = Parse::HTTP::UserAgent->new($self->req->headers->user_agent());

            #Safari needs to use the <object> tag to render SVG correctly with ECMA script too
            if ($ua eq 'Safari') {
                return qq|<object data="$url" type="image/svg+xml" height="100%" width="100%"></object>|;
            #IE9 can handle SVG but not the embedded ECMA script
            } elsif ($ua eq 'MSIE' && $ua >= 9.0 && $ua <= 10.0) {
                return qq|<embed src="$url&forprint=1" type="image/svg+xml" />|;
            #IE prior to v9 need PNG to be safe
            } elsif ($ua eq 'MSIE' && $ua < 9.0) {
                return qq|<img src="$url&png=1" alt="$url" title="PNG conversion of SVG figure. Update your browser for an interactive figure." />|;
            #Everything else assume it can handle HTML5 style SVG with embed tags
            } else {
                return qq|<embed src="$url" type="image/svg+xml" />|;
            }
        }
    );
}

1;
