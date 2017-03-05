package Mira::Model::Content;
$Mira::Model::Content::VERSION = '0.07';

use strict;
use warnings;
use 5.012;

use File::Spec;
use File::Spec::Functions;
use File::Basename qw/basename/;
use Carp;
use Encode;
use Encode::Locale;


sub new {
  my $class = shift;
  my %switches = @_;

  my $source = $switches{source};
  my $ext = $switches{ext} ? $switches{ext} : '.draft';

  my $self = {
    source => $source,
    ext => $ext,
  };

  bless $self, $class;
  return $self;
}


sub floors {
  my $self = shift;
  my $source = $self->{source};

  my $glob = catfile($source, 'content', '*');

  my @content_directory_list = glob encode(locale_fs => $glob);
  @content_directory_list = grep {-d} @content_directory_list;

  my @floors = map {decode(locale_fs => basename($_))} @content_directory_list;

  return \@floors;
}


sub files {
  my $self = shift;
  my $floors = shift;
  my $source = $self->{source};
  my $ext = $self->{ext};

  my $files = {};

  foreach my $floor (@$floors)
  {
    my $glob = catfile($source, 'content', $floor , "*");
    my @entries = glob encode(locale_fs => $glob);
    @entries = grep {-f and not /($ext)$/} @entries;

    foreach my $entry (@entries)
    {
      $entry = decode(locale_fs => $entry);
      push @{ $files->{$floor} }, $entry;
    }
  }

  return $files;
}


1;
