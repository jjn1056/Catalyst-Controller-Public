package Catalyst::Controller::Public;

use Moose;

extends qw/Catalyst::Controller/;
with 'Catalyst::ControllerRole::Public';

our $VERSION = "0.001";

1;

=head1 TITLE

Catalyst::Controller::Public - A controller to serve static files from the public folder

=head1 SYNOPSIS

    use warnings;
    use strict;

    package MyApp::Controller::Static;

    use base 'Catalyst::Controller::Public';

    # localhost/favicon.ico => $HOME/root/static/favicon.ico
    sub favicon :Path('/favicon.ico') { }

    # localhost/css => $HOME/root/static/css
    sub css :Path('/css') { }

And This creates the following public and private endpoints

    .-----------------------------------------------------------------+----------.
    | Class                                                           | Type     |
    +-----------------------------------------------------------------+----------+
    | MyApp::Controller::Static                                       | instance |
    '-----------------------------------------------------------------+----------'

    [debug] Loaded Private actions:
    .----------------------+--------------------------------------+--------------.
    | Private              | Class                                | Method       |
    +----------------------+--------------------------------------+--------------+
    | /static/favicon      | MyApp::Controller::Static            | favicon      |
    | /static/serve_file   | MyApp::Controller::Static            | serve_file   |
    | /static/css          | MyApp::Controller::Static            | css          |
    | /static/end          | MyApp::Controller::Static            | end          |
    | /static/begin        | MyApp::Controller::Static            | begin        |
    '----------------------+--------------------------------------+--------------'

    [debug] Loaded Path actions:
    .-------------------------------------+--------------------------------------.
    | Path                                | Private                              |
    +-------------------------------------+--------------------------------------+
    | /css/...                            | /static/css                          |
    | /favicon.ico/...                    | /static/favicon                      |
    | /static/...                         | /static/serve_file                   |
    '-------------------------------------+--------------------------------------'

So the following URLs would be mapped as so:

    localhost/css => $HOME/root/static/css
    localhost/favicon.ico => $HOME/root/static/favicon.ico
    localhost/static/a/b/c/d  => $HOME/root/static/a/b/c/d

And you can use $c->uri_for for making links:

    $c->uri_for($c->controller('static')->action_for('serve_file', 'base.css'));

=head1 DISCRIPTION

B<Note>This class just extends L<Catalyst::ControllerRole::Public>.  All the main
code is in that role.  You can do the same if it makes sense based on your programming
organization needs.

I prefer to have a controller to manage public assets since I like to use $c->uri_for
and similar to construct paths.  Out of the box this controller does what I think is
the mostly right thing, which is it serves public assets using something like
L<Plack::App::Directory> or L<Plack::App::File> (if I am in production or not)
from $HOME/root/${controller-namespace} and it also makes it easy to create private
paths to public URLs in the way that makes sense to you.

If you inherit from this you will get a public URL endpoint which is the same as the
controller's namespace.  That will serve files under your C<public_path>, which just
defaults as already described.

Althought this controller offers some configuration and features, unlike more complex
systems (see L<Catalyst::Controller::Assets> for example) we do not attempt to full
on 'Rails Asset pipeline' approach, such as building LESS to css or compiling CoffeeScript
to Javascript.  The intention here is to be simple enough for people to use it with
out a lot of documentation pondering.  Also in my experience Javascript developers and
designers prefer to use there own tools and code generation pipelines, over any that
comes bundled with L<Catalyst> (just an observation).  As a result this is aimed at
serving up files that are ready to go.  The assumption is that your Javascript and designers
will use their desired tools and build static versions of thier code into the correct
directory.

=head1 CONFIGURATON

See L<Catalyst::ControllerRole::Public>.

=head1 ACTIONS

See L<Catalyst::ControllerRole::Public>.

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Catalyst>, L<Catalyst::Controller>, L<Plack::App::Directory>.
 
=head1 COPYRIGHT & LICENSE
 
Copyright 2015, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
