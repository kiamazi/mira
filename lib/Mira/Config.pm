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

    $self->{_default}->{post_num} = "3" unless (exists $self->{_default}->{post_num} and $self->{_default}->{post_num});
    $self->{_default}->{archive_post_num} = "20" unless (exists $self->{_default}->{archive_post_num} and $self->{_default}->{archive_post_num});
    $self->{_default}->{feed_post_num} = "20" unless (exists $self->{_default}->{feed_post_num} and $self->{_default}->{feed_post_num});
    $self->{_default}->{default_floor} = "blog" unless (exists $self->{_default}->{default_floor} and $self->{_default}->{default_floor});
    $self->{_default}->{date_format} = "gregorian" unless (exists $self->{_default}->{date_format} and $self->{_default}->{date_format});

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
          $self->{$floor} = _not_valids($floor, $self);
          next;
        }
        $self->{$floor} = $floorconf;
        $self->{$floor}->{title} = $floor unless ($self->{$floor}->{title});
        $self->{$floor}->{description} = $self->{_default}->{description} unless ($self->{$floor}->{description});
        $self->{$floor}->{root} = "$self->{_default}->{root}/$floor" unless ($self->{$floor}->{root});
        $self->{$floor}->{url} = "$self->{_default}->{url}/$floor" unless ($self->{$floor}->{url});
        $self->{$floor}->{static} = $self->{_default}->{static} unless ($self->{$floor}->{static});
        $self->{$floor}->{imageurl} = $self->{_default}->{imageurl} unless ($self->{$floor}->{imageurl});
        $self->{$floor}->{author} = $self->{_default}->{author} unless ($self->{$floor}->{author});
        $self->{$floor}->{email} = $self->{_default}->{email} unless ($self->{$floor}->{email});
        $self->{$floor}->{template} = $self->{_default}->{template} unless ($self->{$floor}->{template});
        $self->{$floor}->{lists} = $self->{_default}->{lists} unless ($self->{$floor}->{lists});
        $self->{$floor}->{namespace} = $self->{_default}->{namespace} unless ($self->{$floor}->{namespace});
        $self->{$floor}->{date_format} = $self->{_default}->{date_format} unless ($self->{$floor}->{date_format});
        $self->{$floor}->{post_num} = $self->{_default}->{post_num} unless $self->{$floor}->{post_num};
        $self->{$floor}->{archive_post_num} = $self->{_default}->{archive_post_num} unless $self->{$floor}->{archive_post_num};
      } else
      {
        $self->{$floor} = _not_valids($floor, $self);
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
    author => $self->{_default}->{author},
    permalink => ":year/:month/:day/:title/",
    default_markup => "markdown",
    post_num => "5",
    archive_post_num => "20",
    static => $self->{_default}->{static},
    imageurl => $self->{_default}->{imageurl},
    template => $self->{_default}->{template},
    lists => $self->{_default}->{lists},
    namespace => $self->{_default}->{namespace},
  };
  return $configs;
}

1;
