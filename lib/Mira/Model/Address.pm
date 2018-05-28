package Mira::Model::Address;
$Mira::Model::Address::VERSION = '00.07.56';

use strict;
use warnings;
use 5.012;

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;
    return $self;
}

sub add {
    my $self     = shift;
    my %switches = @_;

    my $url = $switches{url};

    $self->{$url}->{vars}          = $switches{variables};
    $self->{$url}->{output}        = $switches{output};
    $self->{$url}->{template_root} = $switches{template_root};
    $self->{$url}->{template_file} = $switches{template_file};
    $self->{$url}->{START_TAG}     = $switches{START_TAG};
    $self->{$url}->{END_TAG}       = $switches{END_TAG};
    $self->{$url}->{OUTLINE_TAG}   = $switches{OUTLINE_TAG};
}

1;
