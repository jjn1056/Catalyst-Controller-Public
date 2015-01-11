use warnings;
use strict;

package MyApp::Controller::Static;

use base 'Catalyst::Controller::Public';

sub favicon :Path('/favicon.ico') { }

sub css :Path('/css') { }

#__PACKAGE__->config(allowed_extensions=>undef);
__PACKAGE__->meta->make_immutable;
