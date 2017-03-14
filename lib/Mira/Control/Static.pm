package Mira::Control::Static;
$Mira::Control::Static::VERSION = '00.07.26';

use strict;
use warnings;
use 5.012;

use File::Spec;
use File::Spec::Functions;
use File::Basename;
use File::Copy::Recursive qw(dircopy);

sub address {
  my $class = shift;
  my $statics = shift;
  my $config = shift;
  my $source = shift;
  my $self = {};

  foreach my $floor (keys %{$config}) {
    $floor eq "_default" && next;

    my $floor_static = $config->{$floor}->{static};
    my $floor_path = catdir($source, 'content', $floor);
    foreach my $static (@{ $statics->{$floor} })
    {
      my ($name, $dir) = fileparse($static);
      $name =~ s{^_}{};
      $name = lc $name;
      if ($dir =~ /$floor_path(.*)/)
      {
        my $target = $1;
        my @root_path = split m{/|\\|::}, $config->{$floor}->{root};
        my $address = catdir($source, 'public', @root_path, $target, $name);
        push @{$self->{$floor}}, {path => $static, address => $address} ;
      }
    }
  }

  my @main_root_path = split m{/|\\|::}, $config->{_default}->{static};
  $self->{_default} = [{
    path => catdir($source, 'statics'),
    address => catdir($source, 'public', @main_root_path)
  }];
  return $self;
}


sub copy {
  my $class = shift;
  my $static_path = shift;

  my $total;

  foreach my $floor (keys %{$static_path})
  {
    foreach my $copy (@{$static_path->{$floor}})
    {
      my $copy_num = dircopy(
      catdir($copy->{path}, '/')
      ,
      catdir($copy->{address}, '/')
      );
      say "can't copy ". $copy->{path} . " to " . $copy->{address} . ", check your permisions and try again"
      if not $copy_num;
      $total += $copy_num;
    }
  }
  return $total;
}

1;
