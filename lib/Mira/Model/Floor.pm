package Mira::Model::Floor;

use strict;
use warnings;
use 5.012;
our $VERSION = $Mira::VERSION;

sub new {
  my $class = shift;
  my $self = {};

  bless $self, $class;
  return $self;
}

sub add {
  my $self = shift;
  my $floor = shift;
  my $utid = shift;

  push @{ $self->{$floor} }, $utid;

}

1;
