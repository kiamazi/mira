package Mira::Parser::Markup;
$Mira::Parser::Markup::VERSION = '0.07';

use strict;
use warnings;
use utf8;
use 5.012;

use Markup::Unified;
use Carp;

sub markup {
  my $class = shift;
  my $body = shift;
  my $markup_lang = shift || 'md';

  unless ($markup_lang and $markup_lang =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i)
  {
    $markup_lang = 'markdown' if ($markup_lang !~ /^(markdown|md|html|text|txt|bbcode|textile)$/i);
  } elsif ($markup_lang =~ /^(markdown|md|bbcode|textile|html|text|txt)$/i)
  {
    $markup_lang = $1;
    $markup_lang = 'markdown' if ($markup_lang eq "md");
  }

  if ($markup_lang and $markup_lang =~ /^(markdown|md|bbcode|textile)$/i)
  {
    my $markup = Markup::Unified->new();
    $markup->format($body, "$markup_lang");
    $markup->formatted;
    $body = $markup->{fvalue};
    $body =~ s/(.*)\n$/$1/; #remove new line which make by text::markdown at end
  }

  if ($markup_lang and $markup_lang =~ /^(text|txt)$/i)
  {
    $body =~ s/\n/\n<br>/g;
  }

##### Less and More section #####
  my $fbody = $body;
  $body = {};
  if ($fbody =~ /(?<less>.*)<!--\s*more\s*-->(?<more>.*)/s)
  {
    $body->{less} = $+{less};
    $fbody =~ s:<!--\s*more\s*-->:<a name="more"></a>:;
    $body->{more} = $fbody;
  } else
  {
    my $lessbody = $fbody;
    $lessbody =~ s:<(.*?)>|</(.*?)>::g;
    $lessbody =~ s:^\s*$::mg;
    $lessbody =~ s/(.{0,600}).*/$1/s;
    $body->{less} = "<p>" . $lessbody . "</p>";
    $body->{more} = "<a name=\"more\"></a><br>" . $fbody;
  }

  return $body;
}


1;
