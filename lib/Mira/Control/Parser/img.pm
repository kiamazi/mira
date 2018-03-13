package Mira::Control::Parser::img;
$Mira::Control::Parser::img::VERSION = '00.07.50';

use strict;
use warnings;
use utf8;
use 5.012;


sub replace {
  my $class= shift;
  my $self = shift;
  my $static_img_addr = shift;

  while ($self =~ /(?<!\\)\{\{\s+img\s+([^\s]*?)\s*(\[.*?\])?\s*(\[.*?\])?\s*\}\}/g)
  {
    my $source = $1 if $1;
    my $alt = $2 if $2;
    my $title = $3 ? $3 : ($2 ? $2 : '');
    $alt   =~ s/^\[|\]$/"/g if $alt;
    $title =~ s/^\[|\]$/"/g if $title;
    next unless $source;

    my $imgurl = $static_img_addr;
    $source =~ m{^(.*?)://} ? ($imgurl = $source) : ($imgurl .= "/$source");

    my $addr = "<img src=\"$imgurl\"";
    $addr .= " alt=$alt" if $alt;
    $addr .= " title=$title" if $title;
    $addr .= " >";
    $addr =~ s"(?<!:)/+"/"g;
    $self =~ s/(?<!\\)\{\{\s+img\s+([^\s]*?)\s*(\[.*?\])?\s*(\[.*?\])?\s*\}\}/$addr/;
  }

  $self =~ s/\\\{\{\s+img\s+/\{\{\ img\ /g;
  #$self =~ s/(?<!\\){{\s+img\s+(.*?)\s+(.*?)\s+}}/$imgurl/g;

  return $self;
}


1;
