package Mira::Control::Parser::MiraMarkdown;
$Mira::Control::Parser::MiraMarkdown::VERSION = '00.07.51';

require 5.008_000;
use strict;
use warnings;

use base qw(Text::MultiMarkdown);

our @EXPORT_OK = qw(mira_markdown);

sub mira_markdown {
    my ( $self, $text, $options ) = @_;

    # Detect functional mode, and create an instance for this run
    unless (ref $self) {
        if ( $self ne __PACKAGE__ ) {
            my $ob = __PACKAGE__->new();
                                # $self is text, $text is options
            return $ob->mira_markdown($self, $text);
        }
        else {
            croak('Calling ' . $self . '->markdown (as a class method) is not supported.');
        }
    }

    $options ||= {};

    %$self = (%{ $self->{params} }, %$options, params => $self->{params});

    $self->SUPER::_CleanUpRunData($options);

	$text = $self->_mira_markdown($text);

    return $self->SUPER::_Markdown($text);
}

sub _mira_markdown {
    my ($self, $text) = @_;

	$text =~ s{\r\n}{\n}g;  # DOS to Unix
	$text =~ s{\r}{\n}g;    # Mac to Unix

	$text = $self->_code_block($text);

	return $text;
}

sub _code_block {
	my ($self, $text) = @_;
	my $less_than_tab = $self->{tab_width} - 1;

    while ($text =~ m{
    	^((?<spaces>[ \t]*)```)     # ^([ ]{0,$less_than_tab}```)
    	  [ \t]*(?<class>.*)?$
    	(?<code>[\w\W]*?)
    	(?:^\1|\Z)
    	  \s*\n
    	}omx)
	{
		my $class = $+{class} if $+{class};
        my $spaces = $+{spaces} if $+{spaces};
		if ($class)
		{
			$class = "language-$class" if $class !~ m{^:};
			$class =~ s{^:}{};
		}
		my $code = $+{code} if $+{code};
		if ($code)
		{
			$code =~ s{^\n|\n$}{}g;
			$code = $self->_EncodeCode($code);
        	$code = $self->_Detab($code);
        	$code =~ s/\A\n+//;  # trim leading newlines
	        $code =~ s/\n+\z//;  # trim trailing newlines
            $code =~ s/^$spaces// if $spaces;
		}
		my $pre = $spaces ? $spaces : '';
        $pre .= "<pre><code";
		$pre .= " class=\"$class\"" if $class;
		$pre .= ">";
		$pre .= $code if $code;
		$pre .= "\n</code></pre>\n";

		$text =~ s{
    	^(([ \t]*)```)     # ^([ ]{0,$less_than_tab}```)
    	  [ \t]*(?<class>.*)?$
    	(?<code>[\w\W]*?)
    	(?:^\1|\Z)
    	  \s*\n
    	}{$pre}omx;
	}

	return $text;

}
