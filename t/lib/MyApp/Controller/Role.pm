package MyApp::Controller::Role;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';
with 'Catalyst::ControllerRole::Public';

sub example :Local { }

__PACKAGE__->meta->make_immutable;
