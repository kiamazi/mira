package Mira::Parser::Markup;

use strict;
use warnings;
use utf8;
use 5.012;

use Markup::Unified;
use Carp;

sub markup {
  my $class = shift;
  my $body = shift;
  my $title = shift;
  my $floor = shift;
  my $markup_lang = shift;

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
    #$body->{more} = "<a name=\"more\"></a><br>" . $+{more};
    $fbody =~ s:<!--\s*more\s*-->:<a name="more"></a>:;
    $body->{more} = $fbody;
#    } elsif ($fbody =~ /(?<less>.{0,600})(?<more>.*)/s)
#    {
#      #$body->{full} = $fbody;
#      $body->{less} = $+{less};
#      $body->{more} = $+{more};
  } else
  {
    my $lessbody = $fbody;
    $lessbody =~ s:<(.*?)>|</(.*?)>::g;
    $lessbody =~ s:^\s*$::mg;
    $lessbody =~ s/(.{0,600}).*/$1/s;
    $body->{less} = "<p>" . $lessbody . "</p>";
    $body->{more} = "<a name=\"more\"></a><br>" . $fbody;
    #$body->{full} = "<a name=\"more\"></a><br>" . $fbody;
  }

  return $body;
}


1;
