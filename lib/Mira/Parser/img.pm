package Mira::Parser::img;

use strict;
use warnings;
use utf8;
use 5.012;



sub replace {
  my $class= shift;
  my $self = shift;
  my $imgurl = shift;

  $self =~ s/(?<!\\)\[\%\s+img\s+\%\]/$imgurl/g;

  return $self;
}


1;
