package Mira::CLI::Command::view;

use strict;
use warnings;

use App::Cmd::Setup -command;

use 5.012;

use Cwd;
use Plack::Runner;


my $cwd = cwd;

sub abstract { 'preview server runer' }

sub description { 'start a server with public folder content' }

sub opt_spec {
    return (
	[ 'directory|d=s', 'application path (default: current directory)', { default => $cwd } ],
        [ 'port|p=s',      'port'             ],
        [ 'host|o=s',      'host'             ],
        [ 'help|h',        'this help'        ],

    );
}

sub validate_args {
  my ($self, $opt, $args) = @_;
}

sub execute {
  my ($self, $opt, $args) = @_;
  my $pensource = -d $opt->{directory} ? $opt->{directory} : $cwd;

  print "no public floder in $pensource\n" and exit if not -d "$pensource/public";

  my $app    = Plack::App::IndexFile->new({ root => "$pensource/public" })->to_app;
  my $runner = Plack::Runner->new;
  $runner->parse_options( '--access-log' => '/dev/null', @ARGV );
  $runner->run( $app );

  package Plack::App::IndexFile;

  use parent 'Plack::App::File';

  sub locate_file
  {
      my ($self, $env) = @_;
      my $path         = $env->{PATH_INFO} || '';

      return $self->SUPER::locate_file( $env ) unless $path && $path =~ m{/$};
      $env->{PATH_INFO} .= 'index.html';
      return $self->SUPER::locate_file( $env );
  }

}


1;
