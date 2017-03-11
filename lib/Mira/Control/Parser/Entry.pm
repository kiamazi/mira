package Mira::Control::Parser::Entry;

use strict;
use warnings;
use utf8;
use 5.012;
our $VERSION = $Mira::VERSION;

use YAML;
use Carp;

sub parse {
  my $class = shift;
  my $self = {};
  my %switches = @_;

  my $entry = $switches{entry} or croak "entry parser need entry field";
  my $floor = $switches{floor} or croak "entry parser need floor field";

  my $content;
  my $utid;
  {
    open my $fh, '<:encoding(UTF-8)', $entry or die $!;
    local $/ = undef;
    $content = <$fh>;
    close $fh;
  }

  if ($content =~
  m/
    ^---\s*
    (?<detail>[\w\W]+?)
    ^---\s*
    (?<body>[\w\W]*)
  $/mx)
  {
    my $detail = $+{detail};
    my $body = $+{body};
    $detail =~ s/\s*(?<!\\)#.*//g;
    $detail =~ s/(?<!\\)\\#/#/g;
    $detail =~ s/\\\\#/\\#/g;
    $body =~ s/\n\s*$//;
    if ($detail =~ /^\s*utid\s*:(?<utid>.*)$/m)
    {
      my $top;
      eval
      {
        $top = Load($detail);
      }; if ($@)
      {
        say "problem in HEADER, contetnt HEADER isn't in YAML standard format:
        $entry\n";
        return;
      }
      $utid = delete $top->{utid};
      $utid =~ s/[^\d]//g;
      $self->{utid} = $utid;

      $self->{values}->{_spec}->{file_address} = $entry;

      @{$self->{values}}{keys %$top} = values %$top;

      $self->{values}->{floor} = $floor;
      $self->{values}->{body} = $body;
      $self->{values}->{title} = $utid unless $self->{values}->{title};
    }
  }

  return $self;
}


1;
