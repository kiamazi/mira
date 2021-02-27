package Mira::Control::Content::Load;
$Mira::Control::Content::Load::VERSION = '00.07.56';

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
    my $class    = shift;
    my %switches = @_;

    my $source      = $switches{source};
    my $floorsource = $switches{floorsource};
    my $draft_ext   = $switches{draft_ext};

    my $self = {
        source      => $source,
        draft_ext   => $draft_ext,
        floorsource => $floorsource,
    };

    bless $self, $class;
    return $self;
}

sub floors {
    my $self        = shift;
    my $source      = $self->{source};
    my $floorsource = $self->{floorsource};

    if ( $floorsource and -d $floorsource )
    {
        my $floor = basename($floorsource);
        return [$floor];
    }

    my $glob = catfile( 'content', '*' );

    my @content_directory_list = glob encode( locale_fs => $glob );
    @content_directory_list = grep { -d } @content_directory_list;

    my @floors =
      map { decode( locale_fs => basename($_) ) } @content_directory_list;

    return \@floors;
}

sub files {
    my $self      = shift;
    my $floors    = shift;
    my $source    = $self->{source};
    my $draft_ext = $self->{draft_ext};

    my $files = {};

    foreach my $floor (@$floors)
    {
        my $glob  = catfile( 'content', $floor, "*" );
        my @path  = glob encode( locale_fs => $glob );
        my @files = _room(@path);

        my @entries =
          $draft_ext
          ? grep { -e and !-d and not /($draft_ext)$/ } @files
          : grep { -e and !-d } @files;

        foreach my $entry (@entries)
        {
            $entry = decode( locale_fs => $entry );
            push @{ $files->{$floor} }, $entry;
        }
    }

    return $files;
}

sub statics {
    my $self   = shift;
    my $floors = shift;
    my $source = $self->{source};

    my $statics = {};

    foreach my $floor (@$floors)
    {
        my $glob = catfile( $source, 'content', $floor, "*" );
        my @path = glob encode( locale_fs => $glob );
        @path = grep { -d } @path;
        my @statics = _static_rooms(@path);

        #@statics = grep {-d and /statics$/} @statics;
        foreach my $static (@statics)
        {
            $static = decode( locale_fs => $static );
            push @{ $statics->{$floor} }, $static;
        }
    }

    return $statics;

}

sub _room {
    my @path = @_;
    my @files;
    foreach my $path (@path)
    {
        next if ( -d $path && basename($path) =~ /^_/ );
        ( -e $path && !-d _ ) && ( push @files, $path ) && next;  # if -f $path;
        if ( -d $path )
        {
            my $glob = catfile( $path, "*" );
            my @paths = glob encode( locale_fs => $glob );
            push @files, _room(@paths);
        }
    }
    return @files;
}

sub _static_rooms {
    my @path = @_;
    my @dirs;
    foreach my $path (@path)
    {
        next if not -d $path;
        (push @dirs, $path) && next if ( -d $path && basename($path) =~ /^_/ );
        my $glob = catfile( $path, "*" );
        my @paths = glob encode( locale_fs => $glob );
        @path = grep { -d } @path;
        push @dirs, _static_rooms(@paths);
    }
    return @dirs;
}

1;
