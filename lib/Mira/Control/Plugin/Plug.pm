package Mira::Control::Plugin::Plug;
$Mira::Control::Plugin::Plug::VERSION = '0.0721';

use strict;
use warnings;
use utf8;
use 5.012;

use YAML;# qw'LoadFile';
use Cwd; #qw($bin)
use File::Spec;
use File::Spec::Functions;
use File::Basename qw/basename/;
use Carp;
use Encode;
use Encode::Locale;

use Module::Load;

use lib 'plugins/lib';


sub plug {
  my $class = shift;
  my $source = shift;
  my $plugins = shift;
  my $apis = shift;

  foreach my $plugin (@$plugins)
  {
      #eval "require $plug->{lib}";
      $plugin->{lib} .= '.pm' if $plugin->{lib} !~ /\.pm$/;
      load $plugin->{lib};
      eval {$plugin->{name}->plug($apis)};

      ###### TODO need better checks and error messages ######
#      say "! plugin error: " . $plug_yaml . " > " . $plug->{name} . " need plug method" if $@;
  }


    #my @floors = map {decode(locale_fs => basename($_))} @content_directory_list;

}

1;
