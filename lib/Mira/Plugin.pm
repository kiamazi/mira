package Mira::Plugin;
$Mira::Plugin::VERSION = '0.0721';

use strict;
use warnings;
use utf8;
use 5.012;

sub new {
  my $class = shift;

  my $floor = shift;
  my $data_base = shift;
  my $floors_base = shift;
  my $lists_data = shift;

  my $data;

  foreach my $utid (keys %$data_base) {
    if ($data_base->{$utid}->{floor} eq $floor)
    {
      $data->{$utid} = $data_base->{$utid};
    }
  }

  my $self = {
    floor => $floor,
    data_base => $data,
    floor_data => $floors_base->{$floor},
    lists => $lists_data->{$floor},
  };

#  use Data::Dumper;
#  print Dumper($data);

  bless $self, $class;
  return $self;
}

sub get_floor_name {
  my $self = shift;
  return $self->{floor};
}

sub get_data_base {
  my $self = shift;
  return $self->{data_base};
}

sub get_floor_data {
  my $self = shift;
  return $self->{floor_data};
}

sub get_floor_lists {
  my $self = shift;
  return $self->{lists};
}

1;
