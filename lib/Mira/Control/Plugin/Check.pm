package Mira::Control::Plugin::Check;
$Mira::Control::Plugin::Check::VERSION = '0.0721';

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


sub check {
  my $class = shift;
  my $source = shift;
  my $config = shift;
  my @check;

  if ($config->{plugin}){ foreach my $plugin (@{$config->{plugin}})
  {
    my $yaml;
    eval { $yaml = YAML::LoadFile(catfile($source, 'plugins', $plugin)); 1; } or do { next; };
    if ($yaml->{name} and $yaml->{lib})
    {
      push @check, { name => $yaml->{name}, lib => $yaml->{lib} };
    }
    return \@check;
  }}
}




1;
