package Mira::CLI::Command::view;
$Mira::CLI::Command::new::VERSION = '00.07.39';

use strict;
use warnings;

use App::Cmd::Setup -command;

use 5.012;

use Cwd;
use File::Spec;
use File::Spec::Functions;
#use Plack::Runner;

my $cwd = cwd;

sub abstract { 'preview server runer' }

sub description { 'start a server with publishDIR folder content' }

sub opt_spec {
    return (
	[ 'directory|d=s', 'application path (default: current directory)', { default => $cwd } ],
        [ 'port|p=s',      'port', { default => '5000' }             ],
        [ 'host|o=s',      'host', { default => '127.0.0.1' }        ],
        [ 'help|h',        'this help'        ],

    );
}

sub validate_args {
  my ($self, $opt, $args) = @_;
  my $path = $opt->{directory};
  -d $path or $self->usage_error("directory '$path' does not exist");
  -f catfile($path, 'config.yml') or _usage_error("directory '$path' does not valid address.\ncant't find config.yml");
  -d catdir($path, 'content') or _usage_error("directory '$path' does not valid address.\ncant't find content folder");
  -d catdir($path, 'template') or _usage_error("directory '$path' does not valid address.\ncant't find template folder");
}

sub execute {
  my ($self, $opt, $args) = @_;
  my $source = -d $opt->{directory} ? $opt->{directory} : $cwd;

  my $config = Mira::Config->new($source);
  my $publishDIR = $config->{_default}->{publishDIR};

  our $localdir = catdir($source, $publishDIR);
  print "no publish floder in $localdir\n" and exit if not -d $localdir;

  my $server = MiraStaticServer->new();
  $server->port($opt->{port});
  $server->host($opt->{host});
  $server->run();

  package MiraStaticServer;

  use base qw(HTTP::Server::Simple::CGI);
  use Mira::Server::Static;

  sub handle_request {
      my ( $self, $cgi ) = @_;

      if ( !$self->serve_static( $cgi, $localdir ) ) {
          print "HTTP/1.0 404 Not found\r\n";
          print $cgi->header,
                $cgi->start_html('Not found'),
                $cgi->h1('Not found'),
                $cgi->end_html;
      }
  }

  sub print_banner {
    my $self = shift;

    print( ref($self)
            . ": You can connect to your server at "
            . "http://"
            . $self->host
            . ":"
            . $self->port
            . "/\n" );
  }

#  my $app    = Plack::App::IndexFile->new({ root => $localdir })->to_app;
#  my $runner = Plack::Runner->new;
#  $runner->parse_options( '--access-log' => '/dev/null', @ARGV );
#  $runner->run( $app );
#
#  package Plack::App::IndexFile;
#
#  use parent 'Plack::App::File';
#
#  sub locate_file
#  {
#      my ($self, $env) = @_;
#      my $path         = $env->{PATH_INFO} || '';
#
#      #return $self->SUPER::locate_file( $env ) unless $path && $path =~ m{/$};
#      $env->{PATH_INFO} .= 'index.html' if $env->{PATH_INFO} =~ m{/$};
#      $env->{PATH_INFO} .= '/index.html' unless $env->{PATH_INFO} =~ m{\..*?$};
#      return $self->SUPER::locate_file( $env );
#  }

}

sub _usage_error {
  my $message = shift;
  say "ERROR:";
  say $message;
  exit;
}


1;
