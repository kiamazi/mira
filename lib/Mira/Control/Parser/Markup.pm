package Mira::Control::Parser::Markup;
$Mira::Control::Parser::Markup::VERSION = '00.07.43';

use strict;
use warnings;
use utf8;
use 5.012;

use Markup::Unified;
use Markdent::Simple::Document;
use Carp;

sub markup {
    my $class = shift;
    my $body = shift;
    my $markup_lang = shift || 'md';

    if ($markup_lang and $markup_lang =~ /^(markdown|md|bbcode|textile)$/i)
    {
        $markup_lang = 'markdown' if $markup_lang =~ /^md$/i;
        $markup_lang = lc($markup_lang);
        my $markup = Markup::Unified->new();
        $markup->format($body, $markup_lang);
        $markup->formatted;
        $body = $markup->{fvalue};
        $body =~ s/(.*)\n$/$1/; #remove new line which make by text::markdown at end
    }

    if ($markup_lang and $markup_lang =~ /^(github|ghmd|githubmarkdown)$/i)
    {
        my $markup = Markdent::Simple::Document->new();
        my $html = $markup->markdown_to_html(
            title    => 'Mira',
            dialect  => 'GitHub',
            markdown => $body,
        );
        if ($html =~ m"<body>([\w\W]*)</body>"m) {
            $body = $1;
            my $markup = Markup::Unified->new();
            $markup->format($body, 'markdown');
            $markup->formatted;
            $body = $markup->{fvalue};
        }

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
        $body->{more} = "<a name=\"more\"></a>\n" . $fbody;
    }

    return $body;
}


1;
