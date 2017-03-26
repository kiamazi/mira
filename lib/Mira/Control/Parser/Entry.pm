package Mira::Control::Parser::Entry;
$Mira::Control::Parser::Entry::VERSION = '00.07.30';

use strict;
use warnings;
use utf8;
use 5.012;

use YAML;
use Carp;
use Encode::Guess;

sub parse {
    my $class = shift;
    my $self = {};
    my %switches = @_;

    my $entry = $switches{entry} or croak "entry parser need entry field";
    my $floor = $switches{floor} or croak "entry parser need floor field";

    my $content;
    my $utid;

    {
        open my $fh, "<", $entry or die $!;
        local $/ = undef;
        $content = <$fh>;
        my $enc = guess_encoding($content);
        ref ($enc) or do {say "can't encoding $entry, plz fix it."; return;};
        $content = $enc->decode($content);
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
                say "problem in HEADER, content HEADER isn't in YAML standard format:
                $entry\n";
                return;
            }
            $utid = delete $top->{utid};
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
