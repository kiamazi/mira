package Mira::Plugin;
$Mira::Plugin::VERSION = '00.07.42';

use strict;
use warnings;
use utf8;
use 5.012;

sub new {
  my $class = shift;

  my $floor = shift;
  my $data_base = shift;
  my $archive_base = shift;
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
    lists       => $archive_base->{$floor}->{list},
    dates       => $archive_base->{$floor}->{date},
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
