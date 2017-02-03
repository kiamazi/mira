package Mira::Field;

use strict;
use warnings;

use File::Spec::Functions;
use File::Basename qw/basename/;
use Carp;
use Encode;
use Encode::Locale;
use YAML;

use utf8;
use 5.012;

sub new {
  my $class = shift;
  my $source = shift;
  my $config = shift;

  my $self = {};

  foreach my $floor (keys %$config)
  {
    next if $floor eq "_source";
    if ($config->{$floor}->{lists})
    {
      my @data = @{$config->{$floor}->{lists}};
      foreach my $field (@data)
      {
        $self->{$floor}->{$field} = 'list';
        #$self->{$floor}->{$field} = $floor eq "_default" ? 'global' : 'list';
      }
    }
  }

  bless $self, $class;
  return $self;
}

#return wich floors are exist in floor directory + default if not exist
sub exist_floor_name {
  my $self = shift;
  my @_floors_name = keys %$self;
  return \@_floors_name;
}

#return wich fields are in requested floor or return default fields
sub fields_of_floor {
  my $self = shift;
  my $floor = shift;
    $floor = exists $self->{$floor} ? $floor : 'default';
  my @_fields_name;

  foreach my $fields (keys %{$self->{$floor}})
  {
    push @_fields_name, $fields;
  }

  return \@_fields_name;
}

#detect single, list or global format for a detail
sub field_format {
  my $self = shift;
  my $floor = shift;
    $floor = defined $self->{$floor} ? $floor : 'default';
  my $field = shift;
  return 'single' unless defined $self->{$floor}->{$field};
  return $self->{$floor}->{$field};
}

#list of requested floor's fields or default's fields for creat new entry
sub new_entry_fields {
  my $self = shift;
  my $floor = shift;
    $floor = defined $self->{$floor} ? $floor : 'default';
  my @_fields_name;

  foreach my $fields (keys %{$self->{$floor}})
  {
    push @_fields_name, $fields;
  }

  @_fields_name = grep { $_ !~ /utid|url|template|date|title|body/ } @_fields_name;
  @_fields_name = ('utid', '_index', '_status', '_template', 'date', 'title', @_fields_name, 'body-format');

  return \@_fields_name;
}

1;
