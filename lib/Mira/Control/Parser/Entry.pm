package Mira::Control::Parser::Entry;
$Mira::Control::Parser::Entry::VERSION = '00.07.56';

use strict;
use warnings;
use utf8;
use 5.012;

use YAML;
use Carp;
use File::Basename qw/basename/;
use Encode::Guess;
use POSIX 'strftime';

sub parse {
    my $class = shift;
    my $self = {};
    my %switches = @_;

    my $entry = $switches{entry} or croak "entry parser need entry field";
    my $floor = $switches{floor} or croak "entry parser need floor field";
    my $filename = basename($entry);

    my $content;
    my $utid;

    {
        open my $fh, "<", $entry or die $!;
        local $/ = undef;
        $content = <$fh>;
        my $enc = guess_encoding($content);
        ref($enc) or do {say "can't encoding $entry, plz fix it."; return;};
        $content = $enc->decode($content);
        close $fh;
    }

    if ($content =~
    m/
    ^(---+)?\s*
    (?<detail>[\w\W]+?)
    \n+---+\s*
    (?<body>[\w\W]*)$
    /mx)
    {
        my $detail = $+{detail};
        my $body = $+{body};
        $detail =~ s/\s*(?<!\\)#.*//g;
        $detail =~ s/(?<!\\)\\#/#/g;
        $detail =~ s/\\\\#/\\#/g;
        $body =~ s/\n\s*$//;
#        if ($detail =~ /^utid\s*:(?<utid>.*)$/m)
#        {
        my $top;
        eval
        {
            $top = Load($detail);
        }; if ($@)
        {
            say "problem in HEADER, content HEADER isn't in YAML standard format:
            $entry\n";
            return;
        }
        #$utid = delete $top->{utid};
        if ($top->{utid})
        {
            $utid = $top->{utid};

        } elsif ($top->{date})
        {
            if ( $top->{date} =~
            /^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{1,2}):(\d{1,2})/
            ) {
                my $year  = $1;
                my $month = $2;
                my $day   = $3;
                my $hour  = $4;
                my $min   = $5;
                my $sec   = $6;
                $utid = sprintf "%04d%02d%02d%02d%02d%02d",
                    $year, $month, $day, $hour, $min, $sec;

            } elsif ( $top->{date} =~ /^(\d{4})-(\d{1,2})-(\d{1,2})/ )
            {
                my $year  = $1;
                my $month = $2;
                my $day   = $3;
                $utid = sprintf "%04d%02d%02d", $year, $month, $day;
                my ( $sec, $min, $hour ) = localtime( (lstat $entry)[9] );
                my $datefix = sprintf "%02d%02d%02d", $hour, $min, $sec;
                $utid = $utid . $hour . $min . $sec;

            }
        } elsif ( $filename =~ /^(\d{4})-(\d{1,2})-(\d{1,2})/ )
        {
            my $year  = $1;
            my $month = $2;
            my $day   = $3;
            $utid = sprintf "%04d%02d%02d", $year, $month, $day;
            my ( $sec, $min, $hour ) = localtime( (lstat $entry)[9] );
            my $datefix = sprintf "%02d%02d%02d", $hour, $min, $sec;
            $utid = $utid . $hour . $min . $sec;

        } else
        {
            $utid = strftime("%Y%m%d%H%M%S", localtime( (lstat $entry)[9]) );

        }
        $utid =~ s/[^\d]//g;
        $self->{utid} = $utid;

        foreach my $field (keys %$top)
        {
            if (ref($top->{$field}) eq "ARRAY")
            {
                @{ $top->{$field} } = grep {$_} @{ $top->{$field} };
                delete $top->{$field} unless @{ $top->{$field} };
            }
        }

        $self->{values}->{SPEC}->{file_address} = $entry;

        @{$self->{values}}{keys %$top} = values %$top;

        $self->{values}->{floor} = $floor;
        $self->{values}->{body} = $body;
        unless ($self->{values}->{title})
        {
            $self->{values}->{title} = basename($entry);
            $self->{values}->{title} =~ s/^\d{4}-\d{1,2}-\d{1,2}-//;
            $self->{values}->{title} =~ s/\.(.*)$//;
        }
#        }
    }

    return $self;
}


1;
