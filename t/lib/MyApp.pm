use warnings;
use strict;

package MyApp;

use Catalyst;
use HTTP::Message::PSGI ();

sub redispatch_to {
  my $c = shift;
  my $env = HTTP::Message::PSGI::req_to_psgi(shift);
  our $app ||= $c->psgi_app;

  $c->res->from_psgi_response( $app->($env) );
}

MyApp->setup;
