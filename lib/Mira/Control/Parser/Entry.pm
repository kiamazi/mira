package Mira::Control::Parser::Entry;
$Mira::Control::Parser::Entry::VERSION = '00.07.56';

use strict;
use warnings;
use utf8;
use 5.012;

use YAML;
use Carp;
use File::Basename qw/basename/;
use POSIX 'strftime';

sub parse {
    my $class = shift;
    my $self = {};
    my %switches = @_;

    my $entry = $switches{entry} or croak "entry parser need entry field";
    my $floor = $switches{floor} or croak "entry parser need floor field";

    my $content = _read_file($entry);
    return unless my $post_data = _read_content($content);

    my $detail = $post_data->{detail};
    my $body   = $post_data->{body};

    return if ($detail =~ /^_type\s*:\s*draft\s*$/m);

    my $top;
    eval
    {
        $top = Load($detail);
    }; if ($@)
    {
        say "--- WARNING: problem in HEADER, content HEADER isn't in YAML standard format:
        $entry\n";
        return;
    }

    return if ( $top->{_type} and $top->{_type} =~ /draft/ );

    my $utid = _utid_finder($top, $entry);
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

    return $self;
}


##################


sub _read_file {
    my $entry = shift;
    open my $fh, "<:encoding(UTF-8)", $entry or die $!;
    local $/ = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}
# for support all encoding, not just utf8;
#   use Encode::Guess;
#   my $enc = guess_encoding($content);
#   ref($enc) or do {say "can't encoding $entry, plz fix it."; return;};
#   $content = $enc->decode($content);


sub _read_content {
    my $content = shift;
    if ($content =~
        m/
        ^(---+)?\s*
        (?<detail>[\w\W]+?)
        \n+---+\s*[>|]?\s*
        (?<body>[\w\W]*)$
        /mx)
    {
        return {
            detail => $+{detail},
            body   => $+{body}
        }
    } else {
        return;
    }
}

sub _utid_finder {
    my $top      = shift;
    my $entry    = shift;
    my $filename = basename($entry);
    my $utid;

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

    return $utid;
}

1;
