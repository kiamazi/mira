package Mira::Parser::img;
$Mira::Parser::img::VERSION = '0.0706';

use strict;
use warnings;
use utf8;
use 5.012;



sub replace {
  my $class= shift;
  my $self = shift;
  my $imgurl = shift;

  while ($self =~ /(?<!\\)\{\{\s+img\s+([^\s]*?)\s*(".*?")?\s*(".*?")?\s*\}\}/g)
  {
    my $source = $1 if $1;
    my $alt = $2 if $2;
    my $title = $3 ? $3 : ($2 ? $2 : '');
#    my $title = $2 if (! $3 and $2);
    my $addr = "<img src=\"$imgurl";
    $addr .= "/$source\"" if $source;
    $addr .= "\"" unless $source;
    $addr .= " alt=$alt" if $alt;
    $addr .= " title=$title" if $title;
    $addr .= " >";
    $addr =~ s"(?<!http:)/+"/"g;
    $self =~ s/(?<!\\)\{\{\s+img\s+([^\s]*?)\s*(".*?")?\s*(".*?")?\s*\}\}/$addr/;
  }

  #$self =~ s/(?<!\\){{\s+img\s+(.*?)\s+(.*?)\s+}}/$imgurl/g;

  return $self;
}


1;
