use warnings;
use strict;

package MyApp::Controller::Root;

use base 'Catalyst::Controller';

sub root :Chained(/) PathPrefix CaptureArgs(0) { }

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;
