package Catalyst::Controller::Public;

use Moose;
use MooseX::MethodAttributes;
use Catalyst::Utils;
use Plack::App::Directory;
use Plack::App::File;

extends 'Catalyst::Controller';

our $VERSION = "0.001";
our @DEFAULT_ALLOWED_EXTENSIONS = (qw/txt js jpg jpeg gif png css html gz jar mpg mp3 pdf qt rdf rtf cvs tsv xml zip ico/);

has 'suppress_logs' => (is=>'ro', required=>1, default=>0);

has allow_directory_listing => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_allow_directory_listing');

  sub _build_allow_directory_listing {
    my $self = shift;
    return $self->_app->debug;
  }

has allowed_extensions => (
  is=>'ro',
  isa=>'Maybe[ArrayRef]',
  lazy=>1,
  builder=>'_build_allowed_extensions');

  sub _build_allowed_extensions { \@DEFAULT_ALLOWED_EXTENSIONS }

has _regexp_compiled_allowed_extensions => (
  is=>'ro',
  required=>1,
  lazy=>1,
  default=> sub {
    my $self = shift;
    my $m = join "|", (@{$self->allowed_extensions||[]});
    return qr/\.$m$/;
  });

has static_base => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_static_base');

  sub _build_static_base {
    my $self = shift;
    return File::Spec->catdir($self->_app->config->{root});
  }

has static_parts => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_static_parts');

  sub _build_static_parts {
    my $self = shift;
    my @parts = split '/', $self->action_namespace;
    return File::Spec->catdir(@parts);
  }

has static_path =>  (
  is=>'ro',
  init_arg => undef,
  required=>1,
  lazy=>1,
  builder=>'_build_static_path');

  sub _build_static_path {
    my $self = shift;
    return File::Spec->catdir(
      $self->static_base,
        $self->static_parts);
  }


has 'encoding' => (is=>'ro', predicate=>'has_encoding');
has 'content_type' => (is=>'ro', predicate=>'has_content_type');

has _static_server => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_directory_app',
  init_arg=>undef);

  sub _build_directory_app {
    my $self = shift;
    my %args = (root => $self->static_path);
    my $class = $self->allow_directory_listing ? 'Plack::App::Directory' : 'Plack::App::File';
    $args{encoding} = $self->encoding if $self->has_encoding;
    $args{content_type} = $self->content_type if $self->has_content_type;

    return Plack::App::Directory->new(\%args)->to_app;
  }

sub begin :Private {
  my ($self, $c) = @_;
  $c->log->abort(1) if $self->suppress_logs && $c->log->can('abort');

  if($self->allowed_extensions) {
    my $match = $self->_regexp_compiled_allowed_extensions;
    unless($c->req->path =~m/$match/) {
      my $forbidden = $self->_static_server->return_403;
      $c->res->from_psgi_response($forbidden);
      $c->detach;
    }
  }
}

sub serve_file :Path('') {  }

sub end :Private {
  my ($self, $c) = @_;
  my $env = $c->Catalyst::Utils::env_at_path_prefix;
  $c->res->from_psgi_response($self->_static_server->($env));
}

__PACKAGE__->meta->make_immutable;

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

    __PACKAGE__->meta->make_immutable;

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

=head1 DISCRIPTION

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

If you must change things ( :) ) you have the following configuraiton options

=head2 suppress_logs

Boolean.  Default: true.

By default we suppress most of the Catalyst debugging output on the assumption that it would 
just clutter your terminal.  Set this to a false value (like 0) if you want to see all the
full logs.  Useful if your files are not being served as desired.

=head2 allow_directory_listing

Boolean.  Default: $c->debug

Whether or not you want to serve directories (let people browse your public filesystem).  If
L<Catalyst> is in debug mode (via for example CATALYST_DEBUG=1) this is automatically true.
You can manually control this here if you want.

=head2 allowed_extensions

By default for security purposes we allow a white list of allowed file extensions to be served.
The default list is reasonably extensive:

     (qw/txt js jpg jpeg gif png css html gz jar mpg mp3 pdf qt rdf rtf cvs tsv xml zip ico/);

and its stored in the package variable C<@DEFAULT_ALLOWED_EXTENSIONS>.  You may add more types
for example:

    allowed_extensions => [
      @Catalyst::Controller::Public::DEFAULT_ALLOWED_EXTENSIONS,
      qw/my extra types/), ...

Or you my restrict the list further to exactly only the file extention types you expect to
serve

...Or you may set this to 'undef', in which case we allow everything (you are on your own...).

=head2 static_base

String.  Default: Value of $c->config->{root} (usually $APP_HOME/root)

The base part of where files will be served.  This will be combined with L</static_parts>
to determine the true root of your public files.

=head2 static_parts

String. Default to controller action namespace.

Completes the path to the directory where files are served from.  For example if your
$c->config->{root} = "/home/developer/MyApp/root" and your controller is "MyApp::Controller::Static"
this will point to:

    /home/developer/MyApp/root/static

Since in this case your action namespace is static.

=head2 static_path

This is a read only accessor that gives you the full path to the directory where we will serve
the public files.

=head2 encoding

=head2 content_type

These get passed down to L<Plack::App::Directory> which inherits them from L<Plack::App::File>
so review that package for more information

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Catalyst>, L<Catalyst::Controller>, L<Plack::App::Directory>.
 
=head1 COPYRIGHT & LICENSE
 
Copyright 2015, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
