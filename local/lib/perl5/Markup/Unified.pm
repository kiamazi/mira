package Markup::Unified;

#  ABSTRACT: A simple, unified interface for Textile, Markdown and BBCode.

use warnings;
use strict;
use overload ('fallback' => 1, '""'  => 'formatted');

use Module::Load::Conditional qw/can_load/;

our $VERSION = "1.000000";
$VERSION = eval $VERSION;

=head1 NAME

Markup::Unified - A simple, unified interface for Textile, Markdown and BBCode.

=head1 SYNOPSIS

    use Markup::Unified;

    my $o = Markup::Unified->new();
    my $text = 'h1. A heading';
    $o->format($text, 'textile');

    print $o->formatted; # produces "<h1>A heading</h1>"
    print $o->unformatted; # produces "h1. A heading"

    # you can also just say:
    print $o; # same as "print $o->formatted;"

=head1 DESCRIPTION

This module provides a simple, unified interface for the L<Text::Textile>,
L<Text::Markdown> and L<HTML::BBCode> markup languages modules. This module is
primarily meant to provide a simple way for application developers to deal
with texts that use different markup languages, for example, a message
board where users have the ability to post with their preferred markup language.

Please note that this module expects your texts to be UTF-8.

In order for this module to be useful at any way, at least one of the three
parsing modules (L<Text::Textile>, L<Text::Markdown> or L<HTML::BBCode>)
must be installed. None of these are required, but if you try to parse
a text formatted in any of these markup languages without the respective
module being installed on your system, then the text will be returned
unformatted, and no errors will be raised.

=head1 METHODS

=head2 new()

Creates a new, empty instance of Markup::Unified.

=cut

sub new {
	my $self = {};

	# attempt to load Text::Textile
	if (can_load(modules => { 'Text::Textile' => '2.12' })) {
		$self->{t} = Text::Textile->new;
		$self->{t}->charset('utf-8');
	}

	# attempt to load Text::Markdown
	if (can_load(modules => { 'Text::Markdown' => '1.0.25' })) {
		$self->{m} = Text::Markdown->new;
	}

	# attempt to load HTML::BBCode
	if (can_load(modules => { 'HTML::BBCode' => '2.06' })) {
		$self->{b} = HTML::BBCode->new({ stripscripts => 1, linebreaks => 1 });
	}

	# attempt to load HTML::Truncate
	$self->{trunc} = can_load(modules => { 'HTML::Truncate' => '0.20' }) ? 1 : undef;

	return bless $self, shift;
}

=head2 format( $text, $markup_lang )

Formats the provided text with the provided markup language.
C<$markup_lang> must be one of 'bbcode', 'textile' or 'markdown' (case
insensitive); otherwise the text will remain unprocessed (which is also
true if the appropriate markup module is not installed on your system).

=cut

sub format {
	my ($self, $text, $markup_lang) = @_;

	$self->{value} = $text; # keep unformatted text

	# format according to the formatter
	if ($markup_lang && $markup_lang =~ m/^bbcode/i) {
		$self->{fvalue} = $self->_bbcode($text);
	} elsif ($markup_lang && $markup_lang =~ m/^textile/i) {
		$self->{fvalue} = $self->_textile($text);
	} elsif ($markup_lang && $markup_lang =~ m/^markdown/i) {
		$self->{fvalue} = $self->_markdown($text);
	} else {
		# either no markup language given or unrecognized language
		# so formatted = unformatted
		$self->{fvalue} = $text;
	}

	return $self;
}

=head2 formatted()

Returns the formatted text of the object, with whatever markup language
it was set.

This module also provides the ability to print the formatted version of
an object without calling C<formatted()> explicitly, so you can just use
C<print $obj>.

=cut

sub formatted { $_[0]->{fvalue} }

=head2 unformatted()

Returns the unformatted text of the object.

=cut

sub unformatted { $_[0]->{value} }

=head2 truncate([ $length_str, $ellipsis ])

NOTE: This feature requires the presence of the L<HTML::Truncate> module.
If it is not installed, this method will simply return the output of the
L<formatted()> method without raising any errors.

This method returns the formatted text of the object, truncated according to the
provided length string. This string should be a number followed by one
of the characters 'c' or '%'. For example, C<$length_str = '250c'> will
return 250 characters from the object's text. C<$length_str = '10%'> will
return 10% of the object's text (characterwise). If a length string is
not provided, the text will be truncated to 250 characters by default.

This is useful when you wish to display just a sample of the text, such
as in a list of blog posts, where every listing displays a portion of the
post's text with a "Read More" link to the full text in the end.

If an C<$ellipsis> is provided, it will be used as the text that will be
appended to the truncated HTML (i.e. "Read More"). Read L<HTML::Truncate>'s
documentation for more info. Defaults to &#8230; (HTML entity for the
'...' ellipsis character).

=cut

sub truncate {
	my ($self, $length_str, $ellipsis) = @_;

	# make sure HTML::Truncate is loaded, otherwise just return the
	# formatted text in its entirety
	return $self->formatted unless $self->{trunc};

	my $ht = HTML::Truncate->new(utf8_mode => 1, on_space => 1);

	$length_str =~	m/^(\d+)c$/i ? $ht->chars($1) :
			m/^(\d+)%$/ ? $ht->percent($1) : $ht->chars(250);

	$ht->ellipsis($ellipsis) if $ellipsis;

	return $ht->truncate($self->formatted);
}

=head2 supports( $markup_lang )

Returns a true value if the requested markup language is supported by
this module (which basically means the appropriate module is installed
and loaded). C<$markup_lang> must be one of 'textile', 'bbcode' or 'markdown'
(case insensitive).

Returns a false value if the requested language is not supported.

=cut

sub supports {
	my ($self, $markup_lang) = @_;

	if ($markup_lang =~ m/^textile$/i && $self->{t}) {
		return 1;
	} elsif ($markup_lang =~ m/^markdown$/i && $self->{m}) {
		return 1;
	} elsif ($markup_lang =~ m/^bbcode$/i && $self->{b}) {
		return 1;
	}

	return;
}

##################################################
#     INTERNAL METHODS                           #
##################################################

# format BBCode
sub _bbcode {
	my ($self, $text) = @_;

	return $self->{b} ? $self->{b}->parse($text) : $text;
}

# format Textile
sub _textile {
	my ($self, $text) = @_;

	return $self->{t} ? $self->{t}->textile($text) : $text;
}

# format Markdown
sub _markdown {
	my ($self, $text) = @_;

	return $self->{m} ? $self->{m}->markdown($text) : $text;
}

=head1 DIAGNOSTICS

This module does not throw any exceptions (by itself).

=head1 CONFIGURATION AND ENVIRONMENT
  
C<Markup::Unified> requires no configuration files or environment variables.

=head1 DEPENDENCIES

C<Markup::Unified> B<depends> on the following CPAN modules:

=over

=item * L<Module::Load::Conditional>

=back

C<Markup::Unified> B<needs> one or more of these modules to actually be
of any function:

=over

=item * L<Text::Textile>

=item * L<Text::Markdown>

=item * L<HTML::BBCode>

=item * L<HTML::Truncate>

=back

=head1 INCOMPATIBILITIES WITH OTHER MODULES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-Markup-Unified@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Markup-Unified>.

=head1 AUTHOR

Ido Perlmuter <ido at ido50 dot net>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009-2015, Ido Perlmuter C<< ido at ido50 dot net >>.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself, either version
5.8.1 or any later version. See L<perlartistic|perlartistic> 
and L<perlgpl|perlgpl>.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
__END__
