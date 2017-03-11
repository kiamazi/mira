package Mira::Model::Base;

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
  my $utid = shift;
  my $values = shift;

  $self->{$utid} = $values;

}

1;
