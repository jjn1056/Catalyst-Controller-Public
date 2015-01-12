package MyApp::Controller::Static;

use Moose;
use MooseX::MethodAttributes;

extends  'Catalyst::Controller::Public';

sub favicon :Path('/favicon.ico') { }

sub css :Path('/css') { }

sub mylocal :Local ContentType(text/html) { }

sub not_found :Local File(not_found.txt) { }

#__PACKAGE__->config(allowed_extensions=>undef);
__PACKAGE__->meta->make_immutable;
