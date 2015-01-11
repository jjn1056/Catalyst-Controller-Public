use warnings;
use strict;

package MyApp::Controller::OnChain;

use base 'Catalyst::Controller::Public';

sub onchain :Chained('/root') Args { }

__PACKAGE__->config(no_default_action=>1);
__PACKAGE__->meta->make_immutable;
