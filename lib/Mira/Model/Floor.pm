package Mira::Model::Floor;
$Mira::Model::Floor::VERSION = '00.07.52';

use strict;
use warnings;
use 5.012;

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
