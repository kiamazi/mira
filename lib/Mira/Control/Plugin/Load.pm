package Mira::Control::Plugin::Load;

use strict;
use warnings;
use utf8;
use 5.012;
our $VERSION = $Mira::VERSION;

use Carp;

use Module::Load::Conditional qw(check_install);

use lib 'plugins/lib';


sub check {
  my $class = shift;
  my $source = shift;
  my $config = shift;
  my @check;

  if ($config->{plugin}){ foreach my $plugin (@{$config->{plugin}})
  {
    if (my $chkinst = check_install( module => "Mira::Plugin::$plugin"))
    {
      say "PLUGINS >>> package Mira::Plugin::$plugin is " . ($chkinst ? '' : 'NOT ') . "Loaded";
      push @check, "Mira::Plugin::$plugin";
      next;
    }
    if (my $chkinst = check_install( module => $plugin))
    {
      say "PLUGINS >>> $plugin is " . ($chkinst ? '' : 'NOT ') . "Loaded";
      push @check, $plugin;
      next;
    }
  }}
  return \@check;
}



1;
