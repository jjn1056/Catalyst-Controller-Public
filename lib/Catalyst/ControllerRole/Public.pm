package Catalyst::ControllerRole::Public;

use Moose::Role;
use MooseX::MethodAttributes::Role;
use Catalyst::Utils;
use Plack::App::Directory;
use Plack::App::File;
use Plack::MIME;

with 'MooseX::MethodAttributes::Role::AttrContainer::Inheritable';

our $VERSION = "0.001";
our @DEFAULT_ALLOWED_EXTENSIONS = (keys %{$Plack::MIME::MIME_TYPES});
our %MIME_TO_EXT = ();
while(my ($key, $value) = each %{$Plack::MIME::MIME_TYPES}) {
  push @{$MIME_TO_EXT{lc($value)}}, $key;
}

requires 'register_actions';

has 'suppress_logs' => (is=>'ro', required=>1, default=>0);

has 'no_default_action' => (is=>'ro', required=>1, isa=>'Bool', default=>0);

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

  sub _build_allowed_extensions {
    my $self = shift;
    if($self->has_content_type) {
      my @extensions = @{$MIME_TO_EXT{lc($self->content_type)}||[]};
      $self->_app->log->error("No extensions found for content type '${\$self->content_type}' in ${\ref($self)}")
        unless scalar(@extensions);
      return [\@extensions];
    } else {
      return my $allowed = \@DEFAULT_ALLOWED_EXTENSIONS;
    }
  }

has _regexp_compiled_allowed_extensions => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_regexp_compiled_allowed_extensions');

  sub _build_regexp_compiled_allowed_extensions {
    my $self = shift;
    my $m = join "|", (@{$self->allowed_extensions||[]});
    return my $qr = qr/($m)$/;
  }

has public_base => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_public_base');

  sub _build_public_base {
    my $self = shift;
    return File::Spec->catdir($self->_app->config->{root});
  }

has public_parts => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_public_parts');

  sub _build_public_parts {
    my $self = shift;
    my @parts = split '/', $self->action_namespace;
    return File::Spec->catdir(@parts);
  }

has public_path =>  (
  is=>'ro',
  init_arg => undef,
  required=>1,
  lazy=>1,
  builder=>'_build_public_path');

  sub _build_public_path {
    my $self = shift;
    return File::Spec->catdir(
      $self->public_base,
        $self->public_parts);
  }

has 'encoding' => (is=>'ro', predicate=>'has_encoding');
has 'content_type' => (is=>'ro', predicate=>'has_content_type');

has _static_server => (
  is=>'ro',
  required=>1,
  lazy=>1,
  builder=>'_build_static_server',
  init_arg=>undef);

  sub _build_static_server {
    my $self = shift;
    my %args = (root => $self->public_path);
    my $class = $self->allow_directory_listing ? 'Plack::App::Directory' : 'Plack::App::File';
    $args{encoding} = $self->encoding if $self->has_encoding;
    $args{content_type} = $self->content_type if $self->has_content_type;

    $self->_app->log->debug("Static Path for ${\ref($self)} is ${\$self->public_path}") if $self->_app->debug;
    return $class->new(\%args)->to_app;
  }

sub begin :Private {
  my ($self, $c) = @_;
  $c->log->abort(1) if $self->suppress_logs && $c->log->can('abort');

  if(my ($content_type) = (@{$c->action->attributes->{ContentType}||[]})) {
    my $m = $c->action->{_compiled_ct_regexp} ||= do { join '|', @{$MIME_TO_EXT{lc($content_type)}||[]} };
    unless($c->req->path =~m/($m)$/) {
      $c->res->from_psgi_response([403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden']]);
      $c->detach;
    }
    return;
  }

  if($self->allowed_extensions) {
    my $match = $self->_regexp_compiled_allowed_extensions;
    unless($c->req->path =~m/$match/) {
      $c->res->from_psgi_response([403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden']]);
      $c->detach;
    }
  }
}

after 'register_actions' => sub {
  my ($self, $c) = @_;
  return if $self->no_default_action;
  my $action = $self->create_action(
    name => 'serve_file',
    code => sub { },
    reverse => $self->action_namespace . '/' .'serve_file',
    namespace => $self->action_namespace,
    class => ref($self),
    attributes => {Path => [ $self->action_namespace ] });
  $c->dispatcher->register( $c, $action );
};

sub end :Private {
  my ($self, $c) = @_;
  unless($c->res->body) {
    my $env = $c->Catalyst::Utils::env_at_path_prefix;
    my ($path_info) = (@{$c->action->attributes->{File}||[]});
    $env->{PATH_INFO} = $path_info if $path_info;
    $c->res->from_psgi_response($self->_static_server->($env));
    do { $c->res->body(undef); $c->go('bad_request') } if($c->res->code == 400 and $self->action_for('bad_request'));
    do { $c->res->body(undef); $c->go('forbidden') } if($c->res->code == 403 and $self->action_for('forbidden'));
    do { $c->res->body(undef); $c->go('not_found') } if($c->res->code == 404 and $self->action_for('not_found'));
  }
}

1;

=head1 TITLE

Catalyst::ControllerRole::Public - A controller to serve static files from the public folder

=head1 SYNOPSIS

    package MyApp::Controller::Static;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';
    with 'Catalyst::ControllerRole::Public';

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

=head1 DESCRIPTION

I prefer to have a controller to manage public assets since I like to use $c->uri_for
and similar to construct paths.  Out of the box this controller-role does what I think is
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

=head1 DEFINING ACTIONS

You may define actions in this controller, although by default the 'serve_file' action
(if allowed) will catch and serve static files from the public directory without
you needing to do anything.  You may define actions that expose alternative public
URLs mapped to the public directory, as show in the SYNOPSIS example.  Also, if you add
an action that supplies a body response, we don't attempt to serve a file (use this
for your custom responses).

=head1 CONFIGURATON

If you must change things ( :) ) you have the following configuration options

=head2 suppress_logs

Boolean.  Default: true.

By default we suppress most of the Catalyst debugging output on the assumption that it would 
just clutter your terminal.  Set this to a false value (like 0) if you want to see all the
full logs.  Useful if your files are not being served as desired and you want to debug what
is happening.

=head2 no_default_action

By default we register an action that handles default paths on your Controller.  If you want
to get fancy and have total control over how files get served (for example you want to have
just a specific lists of allowed files associated with actions) you may disable this.

=head2 allow_directory_listing

Boolean.  Default: $c->debug

Whether or not you want to serve directories (let people browse your public filesystem).  If
L<Catalyst> is in debug mode (via for example CATALYST_DEBUG=1) this is automatically true.
You can manually control this here if you want.

=head2 allowed_extensions

By default for security purposes we allow a white list of allowed file extensions to be served.
The default list is reasonably extensive and is taken from L<Plack::MIME>.  Its stored in the
package variable C<@DEFAULT_ALLOWED_EXTENSIONS>.  You may add more types for example:

    allowed_extensions => [
      @Catalyst::ControllerRole::Public::DEFAULT_ALLOWED_EXTENSIONS,
      qw/my extra types/), ...

Or you my restrict the list further to exactly only the file extention types you expect to
serve;

    allowed_extensions => [qw/css js jpg png img/],

...Or you may set this to 'undef', in which case we allow everything (you are on your own...).

B<NOTE:> If you set a L</content_type> then we set the allowed extensions to only those that
are associated with the MIME type by default (and you can override if you find that wise).

=head2 public_base

String.  Default: Value of $c->config->{root} (usually $APP_HOME/root)

The base part of where files will be served.  This will be combined with L</public_parts>
to determine the true root of your public files.

=head2 public_parts

String. Default to controller action namespace.

Completes the path to the directory where files are served from.  For example if your
$c->config->{root} = "/home/developer/MyApp/root" and your controller is "MyApp::Controller::Static"
this will point to:

    /home/developer/MyApp/root/static

Since in this case your action namespace is static.

=head2 public_path

This is a read only accessor that gives you the full path to the directory where we will serve
the public files.

=head2 encoding

=head2 content_type

These get passed down to L<Plack::App::Directory> which inherits them from L<Plack::App::File>
so review that package for more information

=head1 ACTIONS

This Controller defines the following actions.

=head2 begin

=head2 end

Used to determined file eligibility and serve a file from the target directory.

=head2 serve_file

(Exists by default).  Catchall actions for the controller.  Will match anything that
other more specific actions fail to catch.  Tends to have higher priority than
chained actions (you might need to disable this if using chained actions in your
public controllers).

This will probably be your action target for $c->uri_for.

=head1 OPTIONAL ACTIONS

The following actions are optional and are used to customize error responses

=head2 not_found

=head2 forbidden

=head2 bad_request

Create an action with this name if you want custom control over the actual
responses for the preceding errors.  For Example:

    package MyApp::Controller::Static;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';
    with 'Catalyst::ControllerRole::Public';

    sub not_found :Action File(not_found.txt) { } ## $c->{root}/static/not_found.txt

These cannot be private actions.

=head1 ACTION ATTRIBUTES

Actions under a controller that uses this role will recognize the the following
attributes.

=head2 File

Example:

    package MyApp::Controller::Foo;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';
    with 'Catalyst::ControllerRole::Public';

    # http://localhost/foo/not_found => $c->{root} . '/foo' . 'not_found.txt'
    sub not_found :Local File(not_found.txt) { }

Lets you name the file you are serving from the Public URL.

=head2 ContentType

Specify the return content type (and allowed extensions) for the action.  Otherwise
serve all allowed types and guess the entension.

    sub html :Local ContentType(text/html) { }

=head1 AUTHOR
 
See L<Catalyst::Controller::Public>

=head1 COPYRIGHT & LICENSE
 
See L<Catalyst::Controller::Public>

=cut
