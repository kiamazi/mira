package Mira::Config;
$Mira::Config::VERSION = '0.07';

use strict;
use warnings;
use utf8;

use YAML;
use File::Spec;
use File::Spec::Functions;
use File::Basename qw/basename/;
use Carp;
use Encode;
use Encode::Locale;
use File::Path qw(make_path);
use 5.012;

sub new {
  my $class = shift;
  my $source = shift;
  my $self = {};
  #$self->{_source} = $source;

    my $yaml;
    if (-f catfile($source, 'config.yml') )
    {
      {
        open my $fh, '<:encoding(UTF-8)', 'config.yml' or die $!;
        local $/ = undef;
        $yaml = <$fh>;
        close $fh;
      }
      eval { #must read yaml message and print it in error output
        $self->{_default} = Load( $yaml );
      };
      if ($@) {croak "$source/config.yml have problem";}
    } else
    {
      croak " ! - you are not in true path or --source is invalid path or /conf/config.yml isn't valid file";
    }

    $self->{_default}->{root} = "/" unless (exists $self->{_default}->{root} and $self->{_default}->{root});
    $self->{_default}->{root} =~ s{^(.*)?:/+}{/}g;
    $self->{_default}->{root} =~ s{/+}{/}g;
    $self->{_default}->{url} = "/" unless (exists $self->{_default}->{url} and $self->{_default}->{url});
    $self->{_default}->{url} =~ s{(?<!:)/+}{/}g;

    $self->{_default}->{post_num} = "5" unless (exists $self->{_default}->{post_num} and $self->{_default}->{post_num});
    $self->{_default}->{archive_post_num} = "20" unless (exists $self->{_default}->{archive_post_num} and $self->{_default}->{archive_post_num});
    $self->{_default}->{feed_post_num} = "20" unless (exists $self->{_default}->{feed_post_num} and $self->{_default}->{feed_post_num});
    $self->{_default}->{default_floor} = "blog" unless (exists $self->{_default}->{default_floor} and $self->{_default}->{default_floor});
    $self->{_default}->{date_format} = "gregorian" unless (exists $self->{_default}->{date_format} and $self->{_default}->{date_format});
    $self->{_default}->{permalink} = ":year/:month/:day/:title/" unless (exists $self->{_default}->{permalink} and $self->{_default}->{permalink});
    $self->{_default}->{default_markup} = "markdown" unless (exists $self->{_default}->{default_markup} and $self->{_default}->{default_markup});
    $self->{_default}->{default_extension} = "md" unless (exists $self->{_default}->{default_extension} and $self->{_default}->{default_extension});
    $self->{_default}->{static} = "/static" unless (exists $self->{_default}->{static} and $self->{_default}->{static});

    my $glob = catfile($source, 'content', '*');

    my @floors = glob encode(locale_fs => $glob);
    @floors = grep {-d} @floors;
    @floors = map {decode(locale_fs => basename($_))} @floors;

    foreach my $floor (@floors)
    {
      if (-f catfile($source, 'config', "$floor.yml") )
      {
        my $flyaml = catfile($source, 'config', "$floor.yml");
        {
          open my $fh, '<:encoding(UTF-8)', $flyaml or die $!;
          local $/ = undef;
          $yaml = <$fh>;
          close $fh;
        }
        my $floorconf;
        eval { #must read yaml message and print it in error output
          $floorconf = Load($yaml);
        };
        if ($@)
        {
          carp " # - $floor\.yml have problem, use default configs for floor: $floor";
          $floorconf = _not_valids($floor, $self);
        }
        $self->{$floor} = $floorconf;
        $self->{$floor}->{title} = $floor unless ($self->{$floor}->{title});
        $self->{$floor}->{root} = "$self->{_default}->{root}/$floor/" unless ($self->{$floor}->{root});
        $self->{$floor}->{url} = "$self->{_default}->{url}/$floor/" unless ($self->{$floor}->{url});
        $self->{$floor}->{static} = "$self->{$floor}->{root}/static/" unless ($self->{$floor}->{static});
      } else
      {
        $self->{$floor} = _not_valids($floor, $self);
      }

      $self->{$floor}->{url} =~ s{(?<!:)/+}{/}g;
      #$self->{$floor}->{url} =~ s{((?:(?!.*?:)/+))}{/}g;
      $self->{$floor}->{root} =~ s{^(.*?):/+}{/}g;
      $self->{$floor}->{root} =~ s{/+}{/}g;
      $self->{$floor}->{static} =~ s{/+}{/}g;

      foreach my $key (keys %{ $self->{_default} })
      {
        $self->{$floor}->{$key} = $self->{_default}->{$key}
        if (not exists $self->{$floor}->{$key});
      }

    }

    return $self;
}

sub _not_valids {
  my $floor = shift;
  my $self = shift;
  my $configs = {
    title => "$floor",
    root => "$self->{_default}->{root}/$floor/",
    url => "$self->{_default}->{url}/$floor",
    static => "$self->{_default}->{root}/$floor/static",
  };

  return $configs;
}

1;
