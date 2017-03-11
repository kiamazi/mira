package Mira::Plugin;

use strict;
use warnings;
use utf8;
use 5.012;
our $VERSION = $Mira::VERSION;

sub new {
  my $class = shift;

  my $floor = shift;
  my $data_base = shift;
  my $floors_base = shift;
  my $lists_data = shift;
  my $config = shift;

  my $data;

  foreach my $utid (keys %$data_base) {
    if ($data_base->{$utid}->{floor} eq $floor)
    {
      $data->{$utid} = $data_base->{$utid};
    }
  }

  my $self = {
    floor       => $floor,
    data_base   => $data,
#    floor_data => $floors_base->{$floor},
    lists       => $lists_data->{$floor}->{list},
    dates       => $lists_data->{$floor}->{date},
    site_config => $config->{$floor},
    main_config => $config->{_default},
  };

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

#sub get_floor_data {
#  my $self = shift;
#  return $self->{floor_data};
#}

sub get_list_archives {
  my $self = shift;
  return $self->{lists};
}

sub get_date_archives {
  my $self = shift;
  return $self->{dates};
}

sub get_main_config {
  my $self = shift;
  return $self->{main_config};
}

sub get_site_config {
  my $self = shift;
  return $self->{site_config};
}


1;
