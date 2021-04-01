# MarkMoreDown (markmod) -- A modification of John Gruber's original Markdown
#	that adds new features
#
# Original Codes:
#   MarkDown- Copyright (c) 2004-2007 John Gruber
#     <http://daringfireball.net/projects/markdown/>
#   MultiMarkdown Version 2.0.b6- Copyright (c) 2005-2009 Fletcher T. Penney
#     <http://fletcherpenney.net/>
#
#   ---
#
#   MarkMoreDown (c) 2018
#     <http://kiavash.one/>
#
# MarkMoreDown Version 0.0.35
#
# Based on MultiMarkdown Version 2.0.b6

package Text::Markmoredown;
require 5.008_000;
use strict;
use warnings;
use re 'eval';
use utf8;

use Digest::MD5 qw(md5_hex);
use Encode      qw();
use Carp        qw(croak);
use base        'Exporter';
use HTML::Entities qw(encode_entities);
use Text::ASCIIMathML;

our $VERSION   = '0.000036'; # 0.0.36
$VERSION = eval $VERSION;
our @EXPORT_OK = qw(markmod);


# Regex to match balanced [brackets]. See Friedl's
# "Mastering Regular Expressions", 2nd Ed., pp. 328-331.
our ($g_nested_brackets, $g_nested_parens);
$g_nested_brackets = qr{
    (?>                                 # Atomic matching
       [^\[\]]+                         # Anything other than brackets
     |
       \[
         (??{ $g_nested_brackets })     # Recursive set of nested brackets
       \]
    )*
}x;
# Doesn't allow for whitespace, because we're using it to match URLs:
$g_nested_parens = qr{
    (?>                                 # Atomic matching
       [^()\s]+                            # Anything other than parens or whitespace
     |
       \(
         (??{ $g_nested_parens })        # Recursive set of nested brackets
       \)
    )*
}x;

# Table of hash values for escaped characters:
our %g_escape_table;
foreach my $char (split //, '\\`*_{}[]()>#+-.!~') {
    $g_escape_table{$char} = md5_hex($char);
}


sub new {
    my ($class, %p) = @_;

    $p{base_url} ||= ''; # This is the base url to be used for WikiLinks

    $p{tab_width} = 4 unless (defined $p{tab_width} and $p{tab_width} =~ m/^\d+$/);

    $p{document_format} ||= '';

    $p{empty_element_suffix} ||= '>'; # Change to " />" for XHTML output

    $p{heading_ids} = defined $p{heading_ids} ? $p{heading_ids} : 1;
    $p{img_ids}     = defined $p{img_ids}     ? $p{img_ids}     : 1;

    $p{self_url} ||= ''; # Used in footnotes to prepend anchors

    my $self = { params => \%p };
    bless $self, ref($class) || $class;
    return $self;
}

sub markmod {
    my ( $self, $text, $options ) = @_;

    # Detect functional mode, and create an instance for this run
    unless (ref $self) {
        if ( $self ne __PACKAGE__ ) {
            my $ob = __PACKAGE__->new();
                                # $self is text, $text is options
            return $ob->markmod($self, $text);
        }
        else {
            croak('Calling ' . $self . '->markdown (as a class method) is not supported.');
        }
    }

    $options ||= {};

    %$self = (%{ $self->{params} }, %$options, params => $self->{params});

    $self->_CleanUpRunData($options);

    return $self->_Markdown($text);
}

sub _CleanUpRunData {
    my ($self, $options) = @_;
    # Clear the global hashes. If we don't clear these, you get conflicts
    # from other articles when generating a page which contains more than
    # one article (e.g. an index page that shows the N most recent
    # articles):
    $self->{_crossrefs}   = {};
    $self->{_footnotes}   = {};
    $self->{_references}  = {};
    $self->{_used_footnotes}  = []; # Why do we need 2 data structures for footnotes? FIXME
    $self->{_used_references} = []; # Ditto for references
    $self->{_citation_counter} = 0;
    $self->{_attributes}  = {}; # Used for extra attributes on links / images.
    $self->{_urls}        = $options->{urls} ? $options->{urls} : {}; # FIXME - document passing this option (tested in 05options.t).
    $self->{_titles}      = {};
    $self->{_html_blocks} = {};
    # Used to track when we're inside an ordered or unordered list
    # (see _ProcessListItems() for details)
    $self->{_list_level} = 0;

}

sub _Markdown {
#
# Main function. The order in which other subs are called here is
# essential. Link and image substitutions need to happen before
# _EscapeSpecialChars(), so that any *'s or _'s in the <a>
# and <img> tags get encoded.
#
# Can't think of any good way to make this inherit from the Markdown version as ordering is so important, so I've left it.
    my ($self, $text) = @_;

    $text = $self->_CleanUpDoc($text);

    $text = $self->_DoCodeFences($text);

    # Turn block-level HTML blocks into hash entries
    $text = $self->_HashHTMLBlocks($text, {interpret_markdown_on_attribute => 1});

    $text = $self->_StripLinkDefinitions($text);

    $text = $self->_StripMarkdownReferences($text);

    $text = $self->_RunBlockGamut($text, {wrap_in_p_tags => 1});

    $text = $self->_DoMarkdownCitations($text) unless $self->{disable_bibliography};
    $text = $self->_DoFootnotes($text) unless $self->{disable_footnotes};

    $text = $self->_UnescapeSpecialChars($text);

    # This must follow _UnescapeSpecialChars
    $text = $self->_FixFootnoteParagraphs($text) unless $self->{disable_footnotes};  # TODO: remove. Doesn't make any difference to test suite pass/failure
    $text .= $self->_PrintFootnotes() unless $self->{disable_footnotes};
    $text .= $self->_PrintMarkdownBibliography() unless $self->{disable_bibliography};

    $text = $self->_ConvertCopyright($text);

    return $text;

}

sub urls {
    my ( $self ) = @_;

    return $self->{_urls};
}

sub _CleanUpDoc {
    my ($self, $text) = @_;

    # Standardize line endings:
    $text =~ s{\r\n}{\n}g;  # DOS to Unix
    $text =~ s{\r}{\n}g;    # Mac to Unix

    # Make sure $text ends with a couple of newlines:
    $text .= "\n\n";

    # Convert all tabs to spaces.
    $text = $self->_Detab($text);

    # Strip any lines consisting only of spaces and tabs.
    # This makes subsequent regexen easier to write, because we can
    # match consecutive blank lines with /\n+/ instead of something
    # contorted like /[ \t]*\n+/ .
    $text =~ s/^[ \t]+$//mg;

    return $text;
}

sub _StripLinkDefinitions {
#
# Strips link definitions from text, stores the URLs and titles in
# hash references.
#
    my ($self, $text) = @_;

    $text = $self->_StripFootnoteDefinitions($text) unless $self->{disable_footnotes};

    my $less_than_tab = $self->{tab_width} - 1;

    # Link defs are in the form: ^[id]: url "optional title"
    # FIXME - document attributes here.
    while ($text =~ s{
                        # Pattern altered for MultiMarkdown
                        # in order to not match citations or footnotes
                        ^[ ]{0,$less_than_tab}\[([^#^].*)\]:    # id = $1
                          [ \t]*
                          \n?                # maybe *one* newline
                          [ \t]*
                        <?(\S+?)>?            # url = $2
                          [ \t]*
                          \n?                # maybe one newline
                          [ \t]*
                        (?:
                            (?<=\s)            # lookbehind for whitespace
                            ["(]
                            (.+?)            # title = $3
                            [")]
                            [ \t]*
                        )?    # title is optional

                        # MultiMarkdown addition for attribute support
                        \n?
                        (                # Attributes = $4
                            (?<=\s)            # lookbehind for whitespace
                            (([ \t]*\n)?[ \t]*((\S+=\S+)|(\S+=".*?")))*
                        )?
                        [ \t]*
                        # /addition
                        (?:\n+|\Z)
                    }
                    {}mx) {
        $self->{_urls}{lc $1} = $self->_EncodeAmpsAndAngles( $2 );    # Link IDs are case-insensitive
        if ($3) {
            $self->{_titles}{lc $1} = $3;
            $self->{_titles}{lc $1} =~ s/"/&quot;/g;
        }

        # MultiMarkdown addition "
        if ($4) {
            $self->{_attributes}{lc $1} = $4;
        }
        # /addition
    }

    $text = $self->_GenerateImageCrossRefs($text);

    return $text;
}

sub _md5_utf8 {
    # Internal function used to safely MD5sum chunks of the input, which might be Unicode in Perl's internal representation.
    my $input = shift;
    return unless defined $input;
    if (Encode::is_utf8 $input) {
        return md5_hex(Encode::encode('utf8', $input));
    }
    else {
        return md5_hex($input);
    }
}

sub _HashHTMLBlocks {
    my ($self, $text, $options) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    # Hashify HTML blocks (protect from further interpretation by encoding to an md5):
    # We only want to do this for block-level HTML tags, such as headers,
    # lists, and tables. That's because we still want to wrap <p>s around
    # "paragraphs" that are wrapped in non-block-level tags, such as anchors,
    # phrase emphasis, and spans. The list of tags we're looking for is
    # hard-coded:
    my $block_tags = qr{
          (?:
            p         |  div     |  h[1-6]  |  blockquote  |  pre       |  table  |
            dl        |  ol      |  ul      |  script      |  noscript  |  form   |
            fieldset  |  iframe  |  math    |  ins         |  del
          )
        }x;

    my $tag_attrs = qr{
                        (?:                 # Match one attr name/value pair
                            \s+             # There needs to be at least some whitespace
                                            # before each attribute name.
                            [\w.:_-]+       # Attribute name
                            \s*=\s*
                            (?:
                                ".+?"       # "Attribute value"
                             |
                                '.+?'       # 'Attribute value'
                             |
                                [^\s]+?      # AttributeValue (HTML5)
                            )
                        )*                  # Zero or more
                    }x;

    my $empty_tag = qr{< \w+ $tag_attrs \s* />}oxms;
    my $open_tag =  qr{< $block_tags $tag_attrs \s* >}oxms;
    my $close_tag = undef;       # let Text::Balanced handle this
    my $prefix_pattern = undef;  # Text::Balanced
    my $markdown_attr = qr{ \s* markdown \s* = \s* (['"]) (.*?) \1 }xs;

    use Text::Balanced qw(gen_extract_tagged);
    my $extract_block = gen_extract_tagged($open_tag, $close_tag, $prefix_pattern, { ignore => [$empty_tag] });

    my @chunks;
    # parse each line, looking for block-level HTML tags
    while ($text =~ s{^(([ ]{0,$less_than_tab}<)?.*\n)}{}m) {
        my $cur_line = $1;
        if (defined $2) {
            # current line could be start of code block

            my ($tag, $remainder, $prefix, $opening_tag, $text_in_tag, $closing_tag) = $extract_block->($cur_line . $text);
            if ($tag) {
                if ($options->{interpret_markdown_on_attribute} and $opening_tag =~ s/$markdown_attr//i) {
                    my $markdown = $2;
                    if ($markdown =~ /^(1|on|yes)$/) {
                        # interpret markdown and reconstruct $tag to include the interpreted $text_in_tag
                        my $wrap_in_p_tags = $opening_tag =~ /^<(div|iframe)/;
                        $tag = $prefix . $opening_tag . "\n"
                          . $self->_RunBlockGamut($text_in_tag, {wrap_in_p_tags => $wrap_in_p_tags})
                          . "\n" . $closing_tag
                        ;
                    } else {
                        # just remove the markdown="0" attribute
                        $tag = $prefix . $opening_tag . $text_in_tag . $closing_tag;
                    }
                }
                my $key = _md5_utf8($tag);
                $self->{_html_blocks}{$key} = $tag;
                push @chunks, "\n\n" . $key . "\n\n";
                $text = $remainder;
            }
            else {
                # No tag match, so toss $cur_line into @chunks
                push @chunks, $cur_line;
            }
        }
        else {
            # current line could NOT be start of code block
            push @chunks, $cur_line;
        }

    }
    push @chunks, $text;  # whatever is left

    $text = join '', @chunks;

    return $text;
}

sub _HashHR {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    $text =~ s{
                (?:
                    (?<=\n\n)        # Starting after a blank line
                    |                # or
                    \A\n?            # the beginning of the doc
                )
                (                        # save in $1
                    [ ]{0,$less_than_tab}
                    <(hr)                # start tag = $2
                    \b                    # word break
                    ([^<>])*?            #
                    /?>                    # the matching end tag
                    [ \t]*
                    (?=\n{2,}|\Z)        # followed by a blank line or end of document
                )
    }{
        my $key = _md5_utf8($1);
        $self->{_html_blocks}{$key} = $1;
        "\n\n" . $key . "\n\n";
    }egx;

    return $text;
}

sub _HashHTMLComments {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    # Special case for standalone HTML comments:
    $text =~ s{
                (?:
                    (?<=\n\n)        # Starting after a blank line
                    |                # or
                    \A\n?            # the beginning of the doc
                )
                (                        # save in $1
                    [ ]{0,$less_than_tab}
                    (?s:
                        <!
                        (--.*?--\s*)+
                        >
                    )
                    [ \t]*
                    (?=\n{2,}|\Z)        # followed by a blank line or end of document
                )
    }{
        my $key = _md5_utf8($1);
        $self->{_html_blocks}{$key} = $1;
        "\n\n" . $key . "\n\n";
    }egx;

    return $text;
}

sub _HashPHPASPBlocks {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    # PHP and ASP-style processor instructions (<?…?> and <%…%>)
    $text =~ s{
                (?:
                    (?<=\n\n)        # Starting after a blank line
                    |                # or
                    \A\n?            # the beginning of the doc
                )
                (                        # save in $1
                    [ ]{0,$less_than_tab}
                    (?s:
                        <([?%])            # $2
                        .*?
                        \2>
                    )
                    [ \t]*
                    (?=\n{2,}|\Z)        # followed by a blank line or end of document
                )
            }{
                my $key = _md5_utf8($1);
                $self->{_html_blocks}{$key} = $1;
                "\n\n" . $key . "\n\n";
            }egx;
    return $text;
}

sub _RunBlockGamut {
#
# These are all the transformations that form block-level
# tags like paragraphs, headers, and list items.
#
    my ($self, $text, $options) = @_;

    # Do headers first, as these populate cross-refs
    $text = $self->_DoHeaders($text);

    $text = $self->_DoCodeFences($text);

    $text = $self->_DoMathBlocks($text);

    # Do Horizontal Rules:
    my $less_than_tab = $self->{tab_width} - 1;
    $text =~ s{^[ ]{0,$less_than_tab}(\*[ ]?){3,}[ \t]*$}{\n<hr$self->{empty_element_suffix}\n}gmx;
    $text =~ s{^[ ]{0,$less_than_tab}(-[ ]?){3,}[ \t]*$}{\n<hr$self->{empty_element_suffix}\n}gmx;
    $text =~ s{^[ ]{0,$less_than_tab}(_[ ]?){3,}[ \t]*$}{\n<hr$self->{empty_element_suffix}\n}gmx;

    $text = $self->_DoLists($text);

    $text = $self->_DoCodeBlocks($text);

    $text = $self->_DoBlockQuotes($text);

    # We already ran _HashHTMLBlocks() before, in Markdown(), but that
    # was to escape raw HTML in the original Markdown source. This time,
    # we're escaping the markup we've just created, so that we don't wrap
    # <p> tags around block-level tags.
    $text = $self->_HashHTMLBlocks($text);

    # Special case just for <hr />. It was easier to make a special case than
    # to make the other regex more complicated.
    $text = $self->_HashHR($text);

    $text = $self->_HashHTMLComments($text);

    $text = $self->_HashPHPASPBlocks($text);

    $text = $self->_FormParagraphs($text, {wrap_in_p_tags => $options->{wrap_in_p_tags}});

    return $text;
}

sub _RunSpanGamut {
#
# These are all the transformations that occur *within* block-level
# tags like paragraphs, headers, and list items.
#
    my ($self, $text) = @_;

    $text = $self->_DoCodeSpans($text);
    $text = $self->_DoMathSpans($text);
    $text = $self->_EscapeSpecialCharsWithinTagAttributes($text);
    $text = $self->_EscapeSpecialChars($text);

    # Process anchor and image tags. Images must come first,
    # because ![foo][f] looks like an anchor.
    $text = $self->_DoImages($text);
    $text = $self->_DoAnchors($text);

    # Make links out of things like `<http://example.com/>`
    # Must come after _DoAnchors(), because you can use < and >
    # delimiters in inline links like [this](<url>).
    $text = $self->_DoAutoLinks($text);

    $text = $self->_EncodeAmpsAndAngles($text);

    $text = $self->_DoTexeFormating($text);

    # FIXME - Is hard coding space here sane, or does this want to be related to tab width?
    # Do hard breaks:
    $text =~ s/ {2,}\n/ <br$self->{empty_element_suffix}\n/g;

    return $text;
}

sub _EscapeSpecialChars {
    my ($self, $text) = @_;
    my $tokens ||= $self->_TokenizeHTML($text);

    $text = '';   # rebuild $text from the tokens
#   my $in_pre = 0;  # Keep track of when we're inside <pre> or <code> tags.
#   my $tags_to_skip = qr!<(/?)(?:pre|code|kbd|script|math)[\s>]!;

    foreach my $cur_token (@$tokens) {
        if ($cur_token->[0] eq "tag") {
            # Within tags, encode * and _ so they don't conflict
            # with their use in Markdown for italics and strong.
            # We're replacing each such character with its
            # corresponding MD5 checksum value; this is likely
            # overkill, but it should prevent us from colliding
            # with the escape values by accident.
            $cur_token->[1] =~  s! \* !$g_escape_table{'*'}!ogx;
            $cur_token->[1] =~  s! _  !$g_escape_table{'_'}!ogx;
            $text .= $cur_token->[1];
        } else {
            my $t = $cur_token->[1];
            $t = $self->_EncodeBackslashEscapes($t);
            $text .= $t;
        }
    }
    return $text;
}

sub _EscapeSpecialCharsWithinTagAttributes {
#
# Within tags -- meaning between < and > -- encode [\ ` * _] so they
# don't conflict with their use in Markdown for code, italics and strong.
# We're replacing each such character with its corresponding MD5 checksum
# value; this is likely overkill, but it should prevent us from colliding
# with the escape values by accident.
#
    my ($self, $text) = @_;
    my $tokens ||= $self->_TokenizeHTML($text);
    $text = '';   # rebuild $text from the tokens

    foreach my $cur_token (@$tokens) {
        if ($cur_token->[0] eq "tag") {
            $cur_token->[1] =~  s! \\ !$g_escape_table{'\\'}!gox;
            $cur_token->[1] =~  s{ (?<=.)</?code>(?=.)  }{$g_escape_table{'`'}}gox;
            $cur_token->[1] =~  s! \* !$g_escape_table{'*'}!gox;
            $cur_token->[1] =~  s! _  !$g_escape_table{'_'}!gox;
        }
        $text .= $cur_token->[1];
    }
    return $text;
}

sub _DoAnchors {
#
# Turn Markdown link shortcuts into XHTML <a> tags.
#
    my ($self, $text) = @_;

    #
    # First, handle reference-style links: [link text] [id]
    #
    $text =~ s{
        (                   # wrap whole match in $1
          \[
            ($g_nested_brackets)    # link text = $2
          \]

          [ ]?              # one optional space
          (?:\n[ ]*)?       # one optional newline followed by spaces

          \[
            (.*?)       # id = $3
          \]
        )
            (?:
              [ ]?
              \{[ \t]*
              (.+)?
              [ \t]*\}
            )?
    }{
        my $whole_match = $1;
        my $link_text   = $2;
        my $link_id     = lc $3;
        my $attributes  = lc $4 if $4;

        if ($link_id eq "") {
            $link_id = lc $link_text;   # for shortcut links like [this][].
        }

        $link_id =~ s{[ ]*\n}{ }g; # turn embedded newlines into spaces

        $self->_GenerateAnchor($whole_match, $link_text, $link_id, undef, undef, $attributes);
    }xsge;

    #
    # Next, inline-style links: [link text](url "optional title")
    #
    $text =~ s{
        (               # wrap whole match in $1
          \[
            ($g_nested_brackets)    # link text = $2
          \]
          \(            # literal paren
            [ \t]*
            ($g_nested_parens)   # href = $3
            [ \t]*
            (           # $4
              (['"])    # quote char = $5
              (.*?)     # Title = $6
              \5        # matching quote
              [ \t]*    # ignore any spaces/tabs between closing quote and )
            )?          # title is optional
          \)
        )
            (?:
              [ ]?
              \{[ \t]*
              (.+)?
              [ \t]*\}
            )?
    }{
        my $result;
        my $whole_match = $1;
        my $link_text   = $2;
        my $url         = $3;
        my $title       = $6;
        my $attributes  = lc $7 if $7;

        $self->_GenerateAnchor($whole_match, $link_text, undef, $url, $title, $attributes);
    }xsge;

    #
    # Last, handle reference-style shortcuts: [link text]
    # These must come last in case you've also got [link test][1]
    # or [link test](/foo)
    #
    $text =~ s{
        (                    # wrap whole match in $1
          \[
            ([^\[\]]+)        # link text = $2; can't contain '[' or ']'
          \]
        )
            (?:
              [ ]?
              \{[ \t]*
              (.+)?
              [ \t]*\}
            )?
    }{
        my $result;
        my $whole_match = $1;
        my $link_text   = $2;
        (my $link_id    = lc $2) =~ s{[ ]*\n}{ }g; # lower-case and turn embedded newlines into spaces
        my $attributes  = lc $3 if $3;

        $self->_GenerateAnchor($whole_match, $link_text, $link_id, undef, undef, $attributes);
    }xsge;

    return $text;
}

sub _GenerateAnchor {
    # FIXME - Fugly, change to named params?
    my ($self, $whole_match, $link_text, $link_id, $url, $title, $attributes) = @_;

    # Allow automatic cross-references to headers
    if (defined $link_id) {
        my $label = $self->_Header2Label($link_id);
        if (defined $self->{_crossrefs}{$label}) {
            $url ||= $self->{_crossrefs}{$label};
        }
        if ( defined $self->{_titles}{$label} ) {
            $title ||= $self->{_titles}{$label};
        }
#        $attributes ||= $self->_DoAttributes($label);
    }

    my @attributes = split (/ +/, $attributes) if $attributes;
    my $class;
    my $id;
    my $stylus;

    foreach my $attr (@attributes)
    {
        if ($attr =~ m/^\./)
        {
            $attr =~ s/^\.//;
            $class .= " $attr";
        } elsif ($attr =~ m/^\#/)
        {
            $attr =~ s/^\#//;
            $id .= " $attr";
        } else
        {
            $stylus .= " $attr";
        }
    }
    $class  =~ s/^[ ]*// if $class;
    $id     =~ s/^[ ]*// if $id;
    $stylus =~ s/^[ ]*// if $stylus;

    my $result;

#    $attributes = '' unless defined $attributes;

    if ( !defined $url && defined $self->{_urls}{$link_id}) {
        $url = $self->{_urls}{$link_id};
    }

    if (!defined $url) {
        return $whole_match;
    }

    $url =~ s! \* !$g_escape_table{'*'}!gox;    # We've got to encode these to avoid
    $url =~ s!  _ !$g_escape_table{'_'}!gox;    # conflicting with italics/bold.
    $url =~ s{^<(.*)>$}{$1};                    # Remove <>'s surrounding URL, if present

    $result = qq{<a href="$url"};

    if ( !defined $title && defined $link_id && defined $self->{_titles}{$link_id} ) {
        $title = $self->{_titles}{$link_id};
    }

    if ( defined $title ) {
        $title =~ s/"/&quot;/g;
        $title =~ s! \* !$g_escape_table{'*'}!gox;
        $title =~ s!  _ !$g_escape_table{'_'}!gox;
        $result .=  qq{ title="$title"};
    }

    $result .= qq { class="$class"} if $class;
    $result .= qq { id="$id"}       if $id;
    $result .= qq { $stylus}        if $stylus;

    $result .= ">$link_text</a>";
#    $result .= "$attributes>$link_text</a>";

    return $result;
}

sub _DoImages {
#
# Turn Markdown image shortcuts into <img> tags.
#
    my ($self, $text) = @_;

    #
    # First, handle reference-style labeled images: ![alt text][id]
    #
    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.+?)       # alt text = $2
          \]

          [ ]?              # one optional space
          (?:\n[ ]*)?       # one optional newline followed by spaces

          \[
          [ ]?
          \]
        )
            (?:
              [ ]?
              \{[ \t]*
              ([^\}]+)?
              [ \t]*\}
            )?

    }{
        my $result;
        my $whole_match = $1;
        my $alt_text    = $2;
        my $attributes = lc $3 if $3;

        my $link_id = lc $alt_text;     # for shortcut links like ![this][].

        $self->_GenerateImage($whole_match, $alt_text, $link_id, undef, undef, $attributes);
    }xsge;


    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.*?)       # alt text = $2
          \]

          [ ]?              # one optional space
          (?:\n[ ]*)?       # one optional newline followed by spaces

          \[
            (.+)?       # id = $3
          \]
        )
            (?:
              [ ]?
              \{[ \t]*
              ([^\}]+)?
              [ \t]*\}
            )?
    }{
        my $result;
        my $whole_match = $1;
        my $alt_text    = $2;
        my $link_id     = lc $3;
        my $attributes = lc $4 if $4;

        if ($link_id eq '') {
            $link_id = lc $alt_text;     # for shortcut links like ![this][].
        }

        $self->_GenerateImage($whole_match, $alt_text, $link_id, undef, undef, $attributes);
    }xsge;

    #
    # Next, handle inline images:  ![alt text](url "optional title")
    # Don't forget: encode * and _

    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.*?)       # alt text = $2
          \]
          \(            # literal paren
            [ \t]*
            ($g_nested_parens)  # src url - href = $3
            [ \t]*
            (           # $4
              (['"])    # quote char = $5
              (.*?)     # title = $6
              \5        # matching quote
              [ \t]*
            )?          # title is optional
          \)
        )
            (?:
              [ ]?
              \{[ \t]*
              ([^\}]+)?
              [ \t]*\}
            )?
    }{
        my $result;
        my $whole_match = $1;
        my $alt_text    = $2;
        my $url         = $3;
        my $title       = '';
        if (defined($6)) {
            $title      = $6;
        }
        my $attributes = $7 if $7;

        $self->_GenerateImage($whole_match, $alt_text, undef, $url, $title, $attributes);
    }xsge;

    return $text;
}

sub _GenerateImage {
    # FIXME - Fugly, change to named params?
    my ($self, $whole_match, $alt_text, $link_id, $url, $title, $attributes) = @_;

    if (defined $alt_text && length $alt_text) {
        my $label = $self->_Header2Label($alt_text);
        $self->{_crossrefs}{$label} = "#$label";
        $attributes .= $self->{img_ids} ? qq{ #$label} : '';
    }

    my @attributes = split (/ +/, $attributes) if $attributes;
    my $class;
    my $id;
    my $stylus;

    foreach my $attr (@attributes)
    {
        if ($attr =~ m/^\./)
        {
            $attr =~ s/^\.//;
            $class .= " $attr";
        } elsif ($attr =~ m/^\#/)
        {
            $attr =~ s/^\#//;
            $id .= " $attr";
        } else
        {
            $stylus .= " $attr";
        }
    }
    $class  =~ s/^[ ]*// if $class;
    $id     =~ s/^[ ]*// if $id;
    $stylus =~ s/^[ ]*// if $stylus;

#    $attributes .= $self->_DoAttributes($link_id) if defined $link_id;

    my $result;

#    $attributes = '' unless defined $attributes;

    $alt_text ||= '';
    $alt_text =~ s/"/&quot;/g;
    # FIXME - how about >

    if ( !defined $url && defined $self->{_urls}{$link_id}) {
        $url = $self->{_urls}{$link_id};
    }

    # If there's no such link ID, leave intact:
    return $whole_match unless defined $url;

    $url =~ s! \* !$g_escape_table{'*'}!ogx;     # We've got to encode these to avoid
    $url =~ s!  _ !$g_escape_table{'_'}!ogx;     # conflicting with italics/bold.
    $url =~ s{^<(.*)>$}{$1};                    # Remove <>'s surrounding URL, if present

    if (!defined $title && length $link_id && defined $self->{_titles}{$link_id} && length $self->{_titles}{$link_id}) {
        $title = $self->{_titles}{$link_id};
    }

    $result = qq{<img src="$url"};
    $result .= qq{ alt="$alt_text"} if $alt_text;
    $result .= qq{ class="$class"}  if $class;
    $result .= qq{ id="$id"}        if $id;
    $result .= qq{ $stylus}         if $stylus;
    if (defined $title && length $title) {
        $title =~ s! \* !$g_escape_table{'*'}!ogx;
        $title =~ s!  _ !$g_escape_table{'_'}!ogx;
        $title    =~ s/"/&quot;/g;
        $result .=  qq{ title="$title"};
    }
    $result .= $self->{empty_element_suffix};

    return $result;
}

sub _DoHeaders {
    my ($self, $text) = @_;

    # Setext-style headers:
    #     Header 1
    #     ========
    #
    #     Header 2
    #     --------
    #
    $text =~ s{ ^(.+)[ \t]*\n=+[ \t]*(?::(.+))?\n+ }{
        $self->_GenerateHeader('1', $1, $2);
    }egmx;

    $text =~ s{ ^(.+)[ \t]*\n-+[ \t]*(?::(.+))?\n+ }{
        $self->_GenerateHeader('2', $1, $2);
    }egmx;


    # atx-style headers:
    #   # Header 1
    #   ## Header 2
    #   ## Header 2 with closing hashes ##
    #   ...
    #   ###### Header 6
    #
    my $l;
    $text =~ s{
            ^(\#{1,6})  # $1 = string of #'s
            [ \t]*
            (.+?)       # $2 = Header text
            [ \t]*
            (?:\#+:(.+)|\#*)?   # $3 = optional id. optional closing #'s (not counted)
            \n+
        }{
            my $h_level = length($1);
            $self->_GenerateHeader($h_level, $2, $3);
        }egmx;

    $text = $self->_DoTables($text);

    return $text;
}

sub _GenerateHeader {
    my ($self, $level, $id, $label) = @_;

    $label = $self->{heading_ids} ? $self->_Header2Label($id) : '' unless $label;
    my $header = $self->_RunSpanGamut($id);

    if ($label ne '') {
        $self->{_crossrefs}{$label} = "#$label";
        $self->{_titles}{$label} = $header;
        $label = qq{ id="$label"};
    }

    return "<h$level$label>$header</h$level>\n\n";
}

sub _DoLists {
#
# Form HTML ordered (numbered) and unordered (bulleted) lists.
#
    my ($self, $text) = @_;

    $text = $self->_DoDefinitionLists($text)
        unless $self->{disable_definition_lists};

    my $less_than_tab = $self->{tab_width} - 1;

    # Re-usable patterns to match list item bullets and number markers:
    my $marker_ul  = qr/[*+-]/;
    my $marker_ol  = qr/\d+[.]/;
    my $marker_any = qr/(?:$marker_ul|$marker_ol)/;

    # Re-usable pattern to match any entirel ul or ol list:
    my $whole_list = qr{
        (                               # $1 = whole list
          (                             # $2
            [ ]{0,$less_than_tab}
            (${marker_any})             # $3 = first list item marker
            [ \t]+
          )
          (?s:.+?)
          (                             # $4
              \z
            |
              \n{2,}
              (?=\S)
              (?!                       # Negative lookahead for another list item marker
                [ \t]*
                ${marker_any}[ \t]+
              )
          )
          (?:^[ ]{0,$less_than_tab}\^[ \t]*$)?
        )
    }mx;

    # We use a different prefix before nested lists than top-level lists.
    # See extended comment in _ProcessListItems().
    #
    # Note: There's a bit of duplication here. My original implementation
    # created a scalar regex pattern as the conditional result of the test on
    # $self->{_list_level}, and then only ran the $text =~ s{...}{...}egmx
    # substitution once, using the scalar as the pattern. This worked,
    # everywhere except when running under MT on my hosting account at Pair
    # Networks. There, this caused all rebuilds to be killed by the reaper (or
    # perhaps they crashed, but that seems incredibly unlikely given that the
    # same script on the same server ran fine *except* under MT. I've spent
    # more time trying to figure out why this is happening than I'd like to
    # admit. My only guess, backed up by the fact that this workaround works,
    # is that Perl optimizes the substition when it can figure out that the
    # pattern will never change, and when this optimization isn't on, we run
    # afoul of the reaper. Thus, the slightly redundant code to that uses two
    # static s/// patterns rather than one conditional pattern.

    if ($self->{_list_level}) {
        $text =~ s{
                ^
                $whole_list
            }{
                my $list = $1;
                my $marker = $3;
                $list =~ s/\n[ ]{0,$less_than_tab}\^[ \t]*\z//;
                my $list_type = ($marker =~ m/$marker_ul/) ? "ul" : "ol";
                # Turn double returns into triple returns, so that we can make a
                # paragraph for the last item in a list, if necessary:
                $list =~ s/\n{2,}/\n\n\n/g;
                my $result = ( $list_type eq 'ul' ) ?
                    $self->_ProcessListItemsUL($list, $marker_ul)
                  : $self->_ProcessListItemsOL($list, $marker_ol);

                $result = $self->_MakeList($list_type, $result, $marker);
                $result;
            }egmx;
    }
    else {
        $text =~ s{
                (?:(?<=\n\n)|\A\n?)
                $whole_list
            }{
                my $list = $1;
                my $marker = $3;
                $list =~ s/\n[ ]{0,$less_than_tab}\^[ \t]*\z//;
                my $list_type = ($marker =~ m/$marker_ul/) ? "ul" : "ol";
                # Turn double returns into triple returns, so that we can make a
                # paragraph for the last item in a list, if necessary:
                $list =~ s/\n{2,}/\n\n\n/g;
                my $result = ( $list_type eq 'ul' ) ?
                    $self->_ProcessListItemsUL($list, $marker_ul)
                  : $self->_ProcessListItemsOL($list, $marker_ol);
                $result = $self->_MakeList($list_type, $result, $marker);
                $result;
            }egmx;
    }


    return $text;
}

sub _DoDefinitionLists {
    my ($self, $text) = @_;
	# Uses the syntax proposed by Michel Fortin in PHP Markdown Extra

	my $less_than_tab = $self->{tab_width} -1;

	my $line_start = qr{
		[ ]{0,$less_than_tab}
	}mx;

	my $term = qr{
		$line_start
		[^:\s][^\n]*\n
	}sx;

	my $definition = qr{
		\n?[ ]{0,$less_than_tab}
		\:[ \t]+(.*?)\n
		((?=\n?\:)|\n|\Z)	# Lookahead for next definition, two returns,
							# or the end of the document
	}sx;

	my $definition_block = qr{
		((?:$term)+)				# $1 = one or more terms
		((?:$definition)+)			# $2 = by one or more definitions
	}sx;

	my $definition_list = qr{
		(?:$definition_block\n*)+		# One ore more definition blocks
	}sx;

	$text =~ s{
		($definition_list)			# $1 = the whole list
	}{
		my $list = $1;
		my $result = $1;

		$list =~ s{
			(?:$definition_block)\n*
		}{
			my $terms = $1;
			my $defs = $2;

			$terms =~ s{
				[ ]{0,$less_than_tab}
				(.*)
				\s*
			}{
				my $term = $1;
				my $result = "";
				$term =~ s/^\s*(.*?)\s*$/$1/;
				if ($term !~ /^\s*$/){
					$result = "<dt>" . $self->_RunSpanGamut($1) . "</dt>\n";
				}
				$result;
			}xmge;

			$defs =~ s{
				$definition
			}{
				my $def = $1 . "\n";
				$def =~ s/^[ ]{0,$self->{tab_width}}//gm;
				"<dd>\n" . $self->_RunBlockGamut($def) . "\n</dd>\n";
			}xsge;

			$terms . $defs . "\n";
		}xsge;

		"<dl>\n" . $list . "</dl>\n\n";
	}xsge;

	return $text
}

sub _MakeList {
  my ($self, $list_type, $content, $marker) = @_;

  if ($list_type eq 'ol' and $self->{trust_list_start_value}) {
    my ($num) = $marker =~ /^(\d+)[.]/;
    return "<ol start='$num'>\n" . $content . "</ol>\n";
  }

  return "<$list_type>\n" . $content . "</$list_type>\n";
}

sub _ProcessListItemsOL {
#
#   Process the contents of a single ordered list, splitting it
#   into individual list items.
#

    my ($self, $list_str, $marker_any) = @_;


    # The $self->{_list_level} global keeps track of when we're inside a list.
    # Each time we enter a list, we increment it; when we leave a list,
    # we decrement. If it's zero, we're not in a list anymore.
    #
    # We do this because when we're not inside a list, we want to treat
    # something like this:
    #
    #       I recommend upgrading to version
    #       8. Oops, now this line is treated
    #       as a sub-list.
    #
    # As a single paragraph, despite the fact that the second line starts
    # with a digit-period-space sequence.
    #
    # Whereas when we're inside a list (or sub-list), that line will be
    # treated as the start of a sub-list. What a kludge, huh? This is
    # an aspect of Markdown's syntax that's hard to parse perfectly
    # without resorting to mind-reading. Perhaps the solution is to
    # change the syntax rules such that sub-lists must start with a
    # starting cardinal number; e.g. "1." or "a.".

    $self->{_list_level}++;

    # trim trailing blank lines:
    $list_str =~ s/\n{2,}\z/\n/;


    $list_str =~ s{
        (\n)?                           # leading line = $1
        (^[ \t]*)                       # leading whitespace = $2
        ($marker_any) [ \t]+            # list marker = $3
        ((?s:.+?)                       # list item text   = $4
        (\n{1,2}))
        (?= \n* (\z | \2 ($marker_any) [ \t]+))
    }{
        my $item = $4;
        my $leading_line = $1;
        my $leading_space = $2;

        if ($leading_line or ($item =~ m/\n{2,}/)) {
            $item = $self->_RunBlockGamut($self->_Outdent($item), {wrap_in_p_tags => 1});
        }
        else {
            # Recursion for sub-lists:
            $item = $self->_DoLists($self->_Outdent($item));
            chomp $item;
            $item = $self->_RunSpanGamut($item);
        }

        "<li>" . $item . "</li>\n";
    }egmxo;

    $self->{_list_level}--;
    return $list_str;
}

sub _ProcessListItemsUL {
#
#   Process the contents of a single unordered list, splitting it
#   into individual list items.
#

    my ($self, $list_str, $marker_any) = @_;


    # The $self->{_list_level} global keeps track of when we're inside a list.
    # Each time we enter a list, we increment it; when we leave a list,
    # we decrement. If it's zero, we're not in a list anymore.
    #
    # We do this because when we're not inside a list, we want to treat
    # something like this:
    #
    #       I recommend upgrading to version
    #       8. Oops, now this line is treated
    #       as a sub-list.
    #
    # As a single paragraph, despite the fact that the second line starts
    # with a digit-period-space sequence.
    #
    # Whereas when we're inside a list (or sub-list), that line will be
    # treated as the start of a sub-list. What a kludge, huh? This is
    # an aspect of Markdown's syntax that's hard to parse perfectly
    # without resorting to mind-reading. Perhaps the solution is to
    # change the syntax rules such that sub-lists must start with a
    # starting cardinal number; e.g. "1." or "a.".

    $self->{_list_level}++;

    # trim trailing blank lines:
    $list_str =~ s/\n{2,}\z/\n/;


    $list_str =~ s{
        (\n)?                           # leading line = $1
        (^[ \t]*)                       # leading whitespace = $2
        ($marker_any) [ \t]+            # list marker = $3
        ((?s:.+?)                       # list item text   = $4
        (\n{1,2}))
        (?= \n* (\z | \2 ($marker_any) [ \t]+))
    }{
        my $item = $4;
        my $leading_line = $1;
        my $leading_space = $2;

        if ($leading_line or ($item =~ m/\n{2,}/)) {
            $item = $self->_RunBlockGamut($self->_Outdent($item), {wrap_in_p_tags => 1});
        }
        else {
            # Recursion for sub-lists:
            $item = $self->_DoLists($self->_Outdent($item));
            chomp $item;
            $item = $self->_RunSpanGamut($item);
        }

        "<li>" . $item . "</li>\n";
    }egmxo;

    $self->{_list_level}--;
    return $list_str;
}

sub _DoCodeBlocks {
#
# Process Markdown code blocks (indented with 4 spaces or 1 tab):
# * outdent the spaces/tab
# * encode <, >, & into HTML entities
# * escape Markdown special characters into MD5 hashes
# * trim leading and trailing newlines
#

    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

     $text =~ s{
        (?:\n\n|\A)
        (                # $1 = the code block -- one or more lines, starting with a space/tab
          (?:
            (?:[ ]{$self->{tab_width}} | \t)   # Lines must start with a tab or a tab-width of spaces
            .*\n+
          )+
        )
        (?:^[ ]{0,$less_than_tab}\^[ \t]*$)?
        (?=\n|\Z)
    }{
        my $codeblock = $1;
        my $result;  # return value

        $codeblock = $self->_EncodeCode($self->_Outdent($codeblock));
        $codeblock = $self->_Detab($codeblock);
        $codeblock =~ s/\A\n+//;  # trim leading newlines
        $codeblock =~ s/\n+\z//;  # trim trailing newlines

        $result = "\n\n<pre><code>" . $codeblock . "\n</code></pre>\n\n";

        $result;
    }egmx;

    return $text;
}

sub _DoCodeFences {

  my ($self, $text) = @_;

  $text =~ s{
    (?:\n\n|\A)
    (?<!\\)
      (`{3,})                             # start line with triple ` or more ```` $1
        [ \t]*(.*)?\n                     # if exist class $2
            ([\w\W]*?)                    # codeblock $3
      \n\1                                # end with $1
    \s*(?:\n\n|\Z)
  }{
    my $class = $2;
    my $codeblock = $3;

    $class = "language-$class" if ($class and $class !~ m{^:});
    $class =~ s{^:}{};

    my $result;  # return value

    $codeblock = $self->_EncodeCode($codeblock);
    $codeblock = $self->_Detab($codeblock);
    $codeblock =~ s/\A\n+//;  # trim leading newlines
    $codeblock =~ s/\n+\z//;  # trim trailing newlines

    $result = "\n\n<pre><code";
    $result .= " class=\"$class\"" if $class;
    $result .= ">";
    $result .= $codeblock;
    $result .= "\n</code></pre>\n\n";

    $result;
  }egmx;

  return $text;
}

sub _DoCodeSpans {
#
#   *   Backtick quotes are used for <code></code> spans.
#
#   *   You can use multiple backticks as the delimiters if you want to
#       include literal backticks in the code span. So, this input:
#
#         Just type ``foo `bar` baz`` at the prompt.
#
#       Will translate to:
#
#         <p>Just type <code>foo `bar` baz</code> at the prompt.</p>
#
#       There's no arbitrary limit to the number of backticks you
#       can use as delimters. If you need three consecutive backticks
#       in your code, use four for delimiters, etc.
#
#   *   You can use spaces to get literal backticks at the edges:
#
#         ... type `` `bar` `` ...
#
#       Turns to:
#
#         ... type <code>`bar`</code> ...
#

    my ($self, $text) = @_;

    $text =~ s@
            (?<!\\)        # Character before opening ` can't be a backslash
            (`+)        # $1 = Opening run of `
            (.+?)        # $2 = The code block
            (?<!`)
            \1            # Matching closer
            (?!`)
        @
             my $c = "$2";
             $c =~ s/^[ \t]*//g; # leading whitespace
             $c =~ s/[ \t]*$//g; # trailing whitespace
             $c = $self->_EncodeCode($c);
            "<code>$c</code>";
        @egsx;

    return $text;
}

sub _EncodeCode {
#
# Encode/escape certain characters inside Markdown code runs.
# The point is that in code, these characters are literals,
# and lose their special Markdown meanings.
#
    my ($self, $text) = @_;

    local $_ = $text;

    # Encode all ampersands; HTML entities are not
    # entities within a Markdown code span.
    s/&/&amp;/g;

    # Encode $'s, but only if we're running under Blosxom.
    # (Blosxom interpolates Perl variables in article bodies.)
    {
        no warnings 'once';
        if (defined($blosxom::version)) {
            s/\$/&#036;/g;
        }
    }


    # Do the angle bracket song and dance:
    s! <  !&lt;!gx;
    s! >  !&gt;!gx;

    # Now, escape characters that are magic in Markdown:
    s! \* !$g_escape_table{'*'}!ogx;
    s! \+ !$g_escape_table{'+'}!ogx;
    s! \- !$g_escape_table{'-'}!ogx;
    s! _  !$g_escape_table{'_'}!ogx;
    s! ~  !$g_escape_table{'~'}!ogx;
#    s! \^ !$g_escape_table{'^'}!ogx;
    s! {  !$g_escape_table{'{'}!ogx;
    s! }  !$g_escape_table{'}'}!ogx;
    s! \[ !$g_escape_table{'['}!ogx;
    s! \] !$g_escape_table{']'}!ogx;
    s! \\ !$g_escape_table{'\\'}!ogx;

    return $_;
}

sub _DoTexeFormating {
    my ($self, $text) = @_;

    # Handle at beginning of lines:
    $text =~ s{ ^(\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ ^(\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    $text =~ s{ ^(==) (?=\S) (.+?) (?<=\S) \1 }
        {<mark>$2</mark>}gsx;

    $text =~ s{ ^(\+\+) (?=\S) (.+?) (?<=\S) \1 }
        {<ins>$2</ins>}gsx;

    $text =~ s{ ^(\-\-) (?=\S) (.+?) (?<=\S) \1 }
        {<small>$2</small>}gsx;

    $text =~ s{ ^(~~) (?=\S) ((?:.(?!~>))+?) (?<=\S) \1 }
        {<del>$2</del>}gsx;

    $text =~ s{ ^(~~) (?=\S) (.+?) (?<=\S) [ ]? ~> [ ]? (?=\S) (.+?) (?<=\S) \1 }
        {<del>$2</del> <ins>$3</ins>}gsx;

    $text =~ s{ ^(\^) (?=\S) (.+?) (?<=\S) \1 }
        {<sup>$2</sup>}gsx;

    $text =~ s{ ^((?<!~)~(?!~)) (?=\S) (.+?) (?<=\S) \1 }
        {<sub>$2</sub>}gsx;



    # <strong> must go first:
    $text =~ s{ (?<=\W) (\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ (?<=\W) (\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    $text =~ s{ (?<=\W) (==) (?=\S) (.+?) (?<=\S) \1 }
        {<mark>$2</mark>}gsx;

    $text =~ s{ (?<=\W) (\+\+) (?=\S) (.+?) (?<=\S) \1 }
        {<ins>$2</ins>}gsx;

    $text =~ s{ (?<=\W) (\-\-) (?=\S) (.+?) (?<=\S) \1 }
        {<small>$2</small>}gsx;

    $text =~ s{ (?<=\W) (~~) (?=\S) ((?:.(?!~>))+?) (?<=\S) \1 }
        {<del>$2</del>}gsx;

    $text =~ s{ (?<=\W) (~~) (?=\S) (.+?) (?<=\S) [ ]? ~> [ ]? (?=\S) (.+?) (?<=\S) \1 }
        {<del>$2</del> <ins>$3</ins>}gsx;

    $text =~ s{ (?<=\W) (\^) (?=\S) (.+?) (?<=\S) \1 }
        {<sup>$2</sup>}gsx;

    $text =~ s{ (?<=\W) ((?<!~)~(?!~)) (?=\S) (.+?) (?<=\S) \1 }
        {<sub>$2</sub>}gsx;



    # And now, a second pass to catch nested strong and emphasis special cases
    $text =~ s{ (?<=\W) (\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ (?<=\W) (\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    $text =~ s{ (?<=\W) (==) (?=\S) (.+?[=]*) (?<=\S) \1 }
        {<mark>$2</mark>}gsx;

    $text =~ s{ (?<=\W) (\+\+) (?=\S) (.+?[+]*) (?<=\S) \1 }
        {<ins>$2</ins>}gsx;

    $text =~ s{ (?<=\W) (\-\-) (?=\S) (.+?[+]*) (?<=\S) \1 }
        {<small>$2</small>}gsx;

    $text =~ s{ (?<=\W) (~~) (?=\S) ((?:.(?!~>))+?) (?<=\S) \1 }
        {<del>$2</del>}gsx;

    $text =~ s{ (?<=\W) (~~) (?=\S) (.+?) (?<=\S) [ ]? ~> [ ]? (?=\S) (.+?) (?<=\S) \1 }
        {<del>$2</del> <ins>$3</ins>}gsx;

    $text =~ s{ (?<=\W) (\^) (?=\S) (.+?) (?<=\S) \1 }
        {<sup>$2</sup>}gsx;

    $text =~ s{ (?<=\W) ((?<!~)~(?!~)) (?=\S) (.+?) (?<=\S) \1 }
        {<sub>$2</sub>}gsx;

    return $text;
}

sub _DoBlockQuotes {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    $text =~ s{
          (                             # Wrap whole match in $1
            (
              ^[ \t]*>[ \t]?            # '>' at the start of a line
                .+\n                    # rest of the first line
              (.+\n)*                   # subsequent consecutive lines
              \n*                       # blanks
            )+
            (?:^[ ]{0,$less_than_tab}\^[ \t]*$)?
          )
        }{
            my $bq = $1;
            $bq =~ s/\n[ ]{0,$less_than_tab}\^[ \t]*\z//;
            $bq =~ s/^[ \t]*>[ \t]?//gm;    # trim one level of quoting
            $bq =~ s/^[ \t]+$//mg;          # trim whitespace-only lines
            $bq = $self->_RunBlockGamut($bq, {wrap_in_p_tags => 1});      # recurse

            $bq =~ s/^/  /mg;
            # These leading spaces screw with <pre> content, so we need to fix that:
            $bq =~ s{
                    (\s*<pre>.+?</pre>)
                }{
                    my $pre = $1;
                    $pre =~ s/^  //mg;
                    $pre;
                }egsx;

            "<blockquote>\n$bq\n</blockquote>\n\n";
        }egmx;


    return $text;
}


# FIXME - This is really ugly, why do we match stuff and substitute it with the thing we just matched?
sub _GenerateImageCrossRefs {
    my ($self, $text) = @_;

    #
    # First, handle reference-style labeled images: ![alt text][id]
    #
    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.*?)       # alt text = $2
          \]

          [ ]?              # one optional space
          (?:\n[ ]*)?       # one optional newline followed by spaces

          \[
            (.*?)       # id = $3
          \]

        )
    }{
        my $whole_match = $1;
        my $alt_text    = $2;
        my $link_id     = lc $3;

        if ($link_id eq "") {
            $link_id = lc $alt_text;     # for shortcut links like ![this][].
        }

        $alt_text =~ s/"/&quot;/g;

        if (defined $self->{_urls}{$link_id}) {
            my $label = $self->_Header2Label($alt_text);
            $self->{_crossrefs}{$label} = "#$label";
        }

        $whole_match;
    }xsge;

    #
    # Next, handle inline images:  ![alt text](url "optional title")
    # Don't forget: encode * and _

    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.*?)       # alt text = $2
          \]
          \(            # literal paren
            [ \t]*
            <?(\S+?)>?  # src url = $3
            [ \t]*
            (           # $4
              (['"])    # quote char = $5
              (.*?)     # title = $6
              \5        # matching quote
              [ \t]*
            )?          # title is optional
          \)
        )
    }{
        my $result;
        my $whole_match = $1;
        my $alt_text    = $2;

        $alt_text =~ s/"/&quot;/g;
        my $label = $self->_Header2Label($alt_text);
        $self->{_crossrefs}{$label} = "#$label";
        $whole_match;
    }xsge;

    return $text;
}

sub _FindMathEquations{
	my ($self, $text) = @_;

	$text =~ s{
		(\<math[^\>]*)id=\"(.*?)\"> 	# "
	}{
		my $label = Header2Label($2);
		my $header = _RunSpanGamut($2);

		$self->{_crossrefs}{$label} = "#$label";
		$self->{_titles}{$label} = $header;

		$1 . "id=\"$label\">";
	}xsge;

	return $text;
}

sub _DoMathBlocks {
	# Based on Gruber's _DoCodeSpans

	my ($self, $text) = @_;

    $text =~ s{
            (?:\n\n|\A)
			(?<!\\)		    # Character before opening $$ can't be a backslash
			(\$\$)              # $1 = Opening
            [ \t]*              # space or tab
            (?:\[(.+)\])?\n     # $2 = optional label
			(.+?)		        # $3 = The code block
			\n(\1)
            \s*(?:\n\n|\Z)
	}{
        my $m = "$3";
	    my $label = "";
  	    my @attr = (xmlns=>"http://www.w3.org/1998/Math/MathML", display=>"block");

		if (defined $2)
        {
			$label = Header2Label($2);
			my $header = _RunSpanGamut($2);

			$self->{_crossrefs}{$label} = "#$label";
			$self->{_titles}{$label} = $header;
		}
        push(@attr,(id=>"$label")) if ($label ne "");
 		$m =~ s/^[ \t]*//g; # leading whitespace
 		$m =~ s/[ \t]*$//g; # trailing whitespace
        my $mathParser = new Text::ASCIIMathML();
        $m = $mathParser->TextToMathML($m,\@attr);

		"$m";
	}egsx;

    $text =~ s{
            (?:\n\n|\A)
			(?<!\\)		    # Character before opening \\[ can't be a backslash
			(\\\\\[)            # $1 = Opening
            [ \t]*              # space or tab
            (?:\[(.+)\])?\n     # $2 = optional label
			(.+?)		        # $3 = The code block
			\n(\\\\\])
            \s*(?:\n\n|\Z)
	}{
        my $m = "$3";
	    my $label = "";
  	    my @attr = (xmlns=>"http://www.w3.org/1998/Math/MathML", display=>"block");

		if (defined $2)
        {
			$label = Header2Label($2);
			my $header = _RunSpanGamut($2);

			$self->{_crossrefs}{$label} = "#$label";
			$self->{_titles}{$label} = $header;
		}
        push(@attr,(id=>"$label")) if ($label ne "");
 		$m =~ s/^[ \t]*//g; # leading whitespace
 		$m =~ s/[ \t]*$//g; # trailing whitespace
        my @m = split(/\n/, $m);
        my $math;

        my $counter;
        foreach my $x (@m)
        {
            my $mathParser = new Text::ASCIIMathML();
            $math .= $mathParser->TextToMathML($x,\@attr);
            $math .= "<mspace linebreak='newline' />" unless ++$counter == scalar(@m);
        }

		"$math";
	}egsx;

	return $text;
}

sub _DoMathSpans {
	# Based on Gruber's _DoCodeSpans

	my ($self, $text) = @_;

#	$text =~ s{
#			(?<![\\\$])		# Character before opening $ can't be a backslash or $
#			(\$)		# $1 = Opening
#            (?![\$\s])
#			(.+?)		# $2 = The code block
#			(?:\[(.+)\])?	# $3 = optional label
#            (?<=\S)
#			(\1)
#		}{
# 			my $m = "$2";
#			my $label = "";
#			my @attr = (xmlns=>"http://www.w3.org/1998/Math/MathML");
#
#			if (defined $3) {
#				$label = Header2Label($3);
#				my $header = _RunSpanGamut($3);
#
#				$self->{_crossrefs}{$label} = "#$label";
#				$self->{_titles}{$label} = $header;
#			}
# 			$m =~ s/^[ \t]*//g; # leading whitespace
# 			$m =~ s/[ \t]*$//g; # trailing whitespace
#			push(@attr,(id=>"$label")) if ($label ne "");
#			push(@attr,(display=>"inline"));
#
#			my $mathParser = new Text::ASCIIMathML();
#			$m = $mathParser->TextToMathML($m,\@attr);
#			"$m";
#		}egsx;

        $text =~ s{
			(?<!\\)		# Character before opening << can't be a backslash
			(\\\\\()		# $1 = Opening
			(.+?)		# $2 = The code block
			(?:\[(.+)\])?	# $3 = optional label
			(\\\\\))
		}{
 			my $m = "$2";
			my $label = "";
			my @attr = (xmlns=>"http://www.w3.org/1998/Math/MathML");

			if (defined $3) {
				$label = Header2Label($3);
				my $header = _RunSpanGamut($3);

				$self->{_crossrefs}{$label} = "#$label";
				$self->{_titles}{$label} = $header;
			}
 			$m =~ s/^[ \t]*//g; # leading whitespace
 			$m =~ s/[ \t]*$//g; # trailing whitespace
			push(@attr,(id=>"$label")) if ($label ne "");
			push(@attr,(display=>"inline"));

			my $mathParser = new Text::ASCIIMathML();
			$m = $mathParser->TextToMathML($m,\@attr);
			"$m";
		}egsx;

	return $text;
}

sub _StripFootnoteDefinitions {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    while ($text =~ s{
      \n\[\^([^\n]+?)\]\:[ \t]*# id = $1
      \n?
      (.*?)\n{1,2}        # end at new paragraph
      ((?=\n[ ]{0,$less_than_tab}\S)|\Z)    # Lookahead for non-space at line-start, or end of doc
    }
    {\n}sx)
    {
        my $id = $1;
        my $footnote = "$2\n";
        $footnote =~ s/^[ ]{0,$self->{tab_width}}//gm;

        $self->{_footnotes}{$self->_Id2Footnote($id)} = $footnote;
    }

    return $text;
}

sub _DoFootnotes {
    my ($self, $text) = @_;

    return '' unless length $text;

    # First, run routines that get skipped in footnotes
    foreach my $label (sort keys %{ $self->{_footnotes} }) {
        my $footnote = $self->_RunBlockGamut($self->{_footnotes}{$label}, {wrap_in_p_tags => 1});
        $footnote = $self->_UnescapeSpecialChars($footnote);
        $footnote = $self->_DoMarkdownCitations($footnote);
        $self->{_footnotes}{$label} = $footnote;
    }

    my $footnote_counter = 0;

    $text =~ s{
        \[\^(.*?)\]     # id = $1
    }{
        my $result = '';
        my $id = $self->_Id2Footnote($1);

        if (defined $self->{_footnotes}{$id} ) {
            $footnote_counter++;
            if ($self->{_footnotes}{$id} =~ /^glossary:/i) {
                $result = qq{<a href="$self->{self_url}#fn:$id" id="fnref:$id" class="footnote glossary">$footnote_counter</a>};
            }
            else {
                $result = qq{<a href="$self->{self_url}#fn:$id" id="fnref:$id" class="footnote">$footnote_counter</a>};
            }
            push (@{ $self->{_used_footnotes} }, $id);
        }
        $result;
    }xsge;

    return $text;
}

# TODO: remove. Doesn't make any difference to test suite pass/failure
sub _FixFootnoteParagraphs {
    my ($self, $text) = @_;

    $text =~ s(^<p></footnote>)(</footnote>)gm;

    return $text;
}

sub _PrintFootnotes {
    my ($self) = @_;
    my $footnote_counter = 0;
    my $result;

    foreach my $id (@{ $self->{_used_footnotes} }) {
        $footnote_counter++;
        my $footnote = $self->{_footnotes}{$id};

        $footnote =~ s/(<\/(p(re)?|ol|ul)>)$//;
        my $footnote_closing_tag = $1;
        $footnote_closing_tag = '' if !defined $footnote_closing_tag;

        if ($footnote =~ s/^glossary:\s*//i) {
            # Add some formatting for glossary entries

            $footnote =~ s{
                ^(.*?)              # $1 = term
                \s*
                (?:\(([^\(\)]*)\)[^\n]*)?       # $2 = optional sort key
                \n
            }{
                my $glossary = qq{<span class="glossary name">$1</span>};

                if ($2) {
                    $glossary.= qq{<span class="glossary sort" style="display:none">$2</span>};
                };

                $glossary . q{:<p>};
            }egsx;

            $result .= qq{<li id="fn:$id">$footnote<a href="$self->{self_url}#fnref:$id" class="reversefootnote">&#160;&#8617;</a>$footnote_closing_tag</li>\n\n};
        }
        else {
            $result .= qq{<li id="fn:$id">$footnote<a href="$self->{self_url}#fnref:$id" class="reversefootnote">&#160;&#8617;</a>$footnote_closing_tag</li>\n\n};
        }
    }

    if ($footnote_counter > 0) {
        $result = qq[\n\n<div class="footnotes">\n<hr$self->{empty_element_suffix}\n<ol>\n\n] . $result . "</ol>\n</div>";
    }
    else {
        $result = "";
    }

    return $result;
}

sub _Header2Label {
    my ($self, $header) = @_;
    my $label = lc $header;
    $label =~ s/[^\w:_.-]/_/g;        # Strip illegal characters
    while ($label =~ s/^[^\w]//g)
        {};     # Strip illegal leading characters
    return $label;
}

sub _Id2Footnote {
    # Since we prepend "fn:", we can allow leading digits in footnotes
    my ($self, $id) = @_;
    my $footnote = lc $id;
    $footnote =~ s/[^A-Za-z0-9:_.-]//g;     # Strip illegal characters
    return $footnote;
}

sub _DoTables {
    my ($self, $text) = @_;

    return $text if $self->{disable_tables};

    my $less_than_tab = $self->{tab_width} - 1;

    # Algorithm inspired by PHP Markdown Extra's
    # <http://www.michelf.com/projects/php-markdown/>

    # Reusable regexp's to match table

    my $line_start = qr{
        [ ]{0,$less_than_tab}
    }mx;

    my $table_row = qr{
        [^\n]*?\|[^\n]*?\n
    }mx;

    my $first_row = qr{
        $line_start
        \S+.*?\|.*?\n
    }mx;

    my $table_rows = qr{
        (\n?$table_row)
    }mx;

    my $table_caption = qr{
        $line_start
        \[.*?\][ \t]*\n
    }mx;

    my $table_divider = qr{
        $line_start
        [\|\-\:\.][ \-\|\:\.]* \| [ \-\|\:\.]*
    }mx;

    my $whole_table = qr{
        ($table_caption)?       # Optional caption
        ($first_row             # First line must start at beginning
        ($table_row)*?)?        # Header Rows
        $table_divider          # Divider/Alignment definitions
        $table_rows+            # Body Rows
        ($table_caption)?       # Optional caption
    }mx;


    # Find whole tables, then break them up and process them

    $text =~ s{
        ^($whole_table)         # Whole table in $1
        (\n|\Z)                 # End of file or 2 blank lines
    }{
        my $table = $1;
        my $result = qq{<table class="markmod_table">\n};
        my @alignments;
        my $use_row_header = 0;

        # Add Caption, if present

        if ($table =~ s/^$line_start\[\s*(.*?)\s*\](\[\s*(.*?)\s*\])?[ \t]*$//m) {
            if (defined $3) {
                # add caption id to cross-ref list
                my $table_id = $self->_Header2Label($3);
                $result .= qq{<caption id="$table_id">} . $self->_RunSpanGamut($1). "</caption>\n";

                $self->{_crossrefs}{$table_id} = "#$table_id";
                $self->{_titles}{$table_id} = "$1";
            }
            else {
                $result .= "<caption>" . $self->_RunSpanGamut($1). "</caption>\n";
            }
        }

        # If a second "caption" is present, treat it as a summary
        # However, this is not valid in XHTML 1.0 Strict
        # But maybe in future

        # A summary might be longer than one line
        if ($table =~ s/\n$line_start\[\s*(.*?)\s*\][ \t]*\n/\n/s) {
            # $result .= "<summary>" . $self->_RunSpanGamut($1) . "</summary>\n";
        }

        # Now, divide table into header, alignment, and body

        # First, add leading \n in case there is no header

        $table = "\n" . $table;

        # Need to be greedy

        $table =~ s/\n($table_divider)\n(($table_rows)+)//s;

        my $alignment_string = $1;
        my $body = $2;

        # Process column alignment
        while ($alignment_string =~ /\|?\s*(.+?)\s*(\||\Z)/gs) {
            my $cell = $self->_RunSpanGamut($1);
            if ($cell =~ /\:$/) {
                if ($cell =~ /^\:/) {
                    $result .= qq[<col align="center"$self->{empty_element_suffix}\n];
                    push(@alignments,"center");
                }
                else {
                    $result .= qq[<col align="right"$self->{empty_element_suffix}\n];
                    push(@alignments,"right");
                }
            }
            else {
                if ($cell =~ /^\:/) {
                    $result .= qq[<col align="left"$self->{empty_element_suffix}\n];
                    push(@alignments,"left");
                }
                else {
                    if (($cell =~ /^\./) || ($cell =~ /\.$/)) {
                        $result .= qq[<col align="char"$self->{empty_element_suffix}\n];
                        push(@alignments,"char");
                    }
                    else {
                        $result .= "<col$self->{empty_element_suffix}\n";
                        push(@alignments,"");
                    }
                }
            }
        }

        # Process headers
        $table =~ s/^\n+//s;

        $result .= "<thead>\n";

        # Strip blank lines
        $table =~ s/\n[ \t]*\n/\n/g;

        foreach my $line (split(/\n/, $table)) {
            # process each line (row) in table
            $result .= "<tr>\n";
            my $count=0;
            while ($line =~ /\|?\s*([^\|]+?)\s*(\|+|\Z)/gs) {
                # process contents of each cell
                my $cell = $self->_RunSpanGamut($1);
                my $ending = $2;
                my $colspan = "";
                if ($ending =~ s/^\s*(\|{2,})\s*$/$1/) {
                    $colspan = " colspan=\"" . length($ending) . "\"";
                }
                $result .= "\t<th$colspan>$cell</th>\n";
                if ( $count == 0) {
                    if ($cell =~ /^\s*$/) {
                        $use_row_header = 1;
                    }
                    else {
                        $use_row_header = 0;
                    }
                }
                $count++;
            }
            $result .= "</tr>\n";
        }

        # Process body

        $result .= "</thead>\n<tbody>\n";

        foreach my $line (split(/\n/, $body)) {
            # process each line (row) in table
            if ($line =~ /^\s*$/) {
                $result .= "</tbody>\n\n<tbody>\n";
                next;
            }
            $result .= "<tr>\n";
            my $count=0;
            while ($line =~ /\|?\s*([^\|]+?)\s*(\|+|\Z)/gs) {
                # process contents of each cell
                no warnings 'uninitialized';
                my $cell = $self->_RunSpanGamut($1);
                my $ending = $2;
                my $colspan = "";
                my $cell_type = "td";
                if ($count == 0 && $use_row_header == 1) {
                    $cell_type = "th";
                }
                if ($ending =~ s/^\s*(\|{2,})\s*$/$1/) {
                    $colspan = " colspan=\"" . length($ending) . "\"";
                }
                if ($alignments[$count] !~ /^\s*$/) {
                    $result .= "\t<$cell_type$colspan align=\"$alignments[$count]\">$cell</$cell_type>\n";
                }
                else {
                    $result .= "\t<$cell_type$colspan>$cell</$cell_type>\n";
                }
                $count++;
            }
            $result .= "</tr>\n";
        }

        $result .= "</tbody>\n</table>\n";
        $result
    }egmx;

    my $table_body = qr{
        (                               # wrap whole match in $2

            (.*?\|.*?)\n                    # wrap headers in $3

            [ ]{0,$less_than_tab}
            ($table_divider)    # alignment in $4

            (                           # wrap cells in $5
                $table_rows
            )
        )
    }mx;

    return $text;
}

sub _DoAttributes {
    my ($self, $id) = @_;
    my $result = "";

    if (defined $self->{_attributes}{$id}) {
        while ($self->{_attributes}{$id} =~ s/(\S+)="(.*?)"//) {
            $result .= qq{ $1="$2"};
        }
        while ($self->{_attributes}{$id} =~ /(\S+)=(\S+)/g) {
            $result .= qq{ $1="$2"};
        }
    }

    return $result;
}

sub _StripMarkdownReferences {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    while ($text =~ s{
        \n\[\#(.+?)\]:[ \t]*    # id = $1
        \n?
        (.*?)\n{1,2}            # end at new paragraph
        ((?=\n[ ]{0,$less_than_tab}\S)|\Z)  # Lookahead for non-space at line-start, or end of doc
    }
    {\n}sx)
    {
        my $id = $1;
        my $reference = "$2\n";

        $reference =~ s/^[ ]{0,$self->{tab_width}}//gm;

        $reference = $self->_RunBlockGamut($reference, {wrap_in_p_tags => 0});

        $self->{_references}{$id} = $reference;
    }

    return $text;
}

sub _DoMarkdownCitations {
    my ($self, $text) = @_;

    $text =~ s{
        \[([^\[]*?)\]       # citation text = $1
        [ ]?            # one optional space
        (?:\n[ ]*)?     # one optional newline followed by spaces
        \[\#(.*?)\]     # id = $2
    }{
        my $result;
        my $anchor_text = $1;
        my $id = $2;
        my $count;

        if (defined $self->{_references}{$id} ) {
            my $citation_counter=0;

            # See if citation has been used before
            foreach my $old_id (@{ $self->{_used_references} }) {
                $citation_counter++;
                $count = $citation_counter if ($old_id eq $id);
            }

            if (! defined $count) {
                $count = ++$self->{_citation_counter};
                push (@{ $self->{_used_references} }, $id);
            }

            $result = qq[<span class="markdowncitation"> (<a href="#$id">$count</a>];

            if ($anchor_text ne "") {
                $result .= qq[, <span class="locator">$anchor_text</span>];
            }

            $result .= ")</span>";
        }
        else {
            # No reference exists
            $result = qq[<span class="externalcitation"> (<a id="$id">$id</a>];

            if ($anchor_text ne "") {
                $result .= qq[, <span class="locator">$anchor_text</span>];
            }

            $result .= ")</span>";
        }

        if ($self->_Header2Label($anchor_text) eq "notcited"){
            $result = qq[<span class="notcited" id="$id"/>];
        }
        $result;
    }xsge;

    return $text;
}

sub _PrintMarkdownBibliography {
    my ($self) = @_;
    my $citation_counter = 0;
    my $result;

    foreach my $id (@{ $self->{_used_references} }) {
        $citation_counter++;
        $result .= qq|<div id="$id"><p>[$citation_counter] <span class="item">$self->{_references}{$id}</span></p></div>\n\n|;
    }
    $result .= "</div>";

    if ($citation_counter > 0) {
        $result = qq[\n\n<div class="bibliography">\n<hr$self->{empty_element_suffix}\n\n] . $result;
    }
    else {
        $result = "";
    }

    return $result;
}

sub _FormParagraphs {
#
#   Params:
#       $text - string to process with html <p> tags
#
    my ($self, $text, $options) = @_;

    # Strip leading and trailing lines:
    $text =~ s/\A\n+//;
    $text =~ s/\n+\z//;

    my @grafs = split(/\n{2,}/, $text);

    #
    # Wrap <p> tags.
    #
    foreach my $graf (@grafs) {
        unless (defined( $self->{_html_blocks}{$graf} )) {
            $graf = $self->_RunSpanGamut($graf);
            my $attribute;
            $graf =~ s{
                \n
                \{\=[ \t]?(.+?)[ \t]?\}$
            }{
                $attribute = $1;
                '';
            }xse;

            my @attributes = split (/ +/, $attribute) if $attribute;
            my $class;
            my $id;
            my $stylus;

            foreach my $attr (@attributes)
            {
                if ($attr =~ m/^\./)
                {
                    $attr =~ s/^\.//;
                    $class .= " $attr";
                } elsif ($attr =~ m/^\#/)
                {
                    $attr =~ s/^\#//;
                    $id .= " $attr";
                } else
                {
                    $stylus .= " $attr";
                }
            }
            $class  =~ s/^[ ]*// if $class;
            $id     =~ s/^[ ]*// if $id;
            $stylus =~ s/^[ ]*// if $stylus;


            if ($options->{wrap_in_p_tags}) {
                my $opt = qq{<p};
                $opt .= qq{ class="$class"} if $class;
                $opt .= qq{ id="$id"} if $id;
                $opt .= qq{ $stylus} if $stylus;
                $opt .= ">";

                $graf =~ s/^([ \t]*)/$opt/;
                $graf .= "</p>"
            }
        }
    }

    #
    # Unhashify HTML blocks
    #
    foreach (@grafs) {
        if (defined( $self->{_html_blocks}{$_} )) {
            $_ = $self->{_html_blocks}{$_};
        }
    }

    return join "\n\n", @grafs;
}

sub _EncodeAmpsAndAngles {
# Smart processing for ampersands and angle brackets that need to be encoded.

    my ($self, $text) = @_;
    return '' if (!defined $text or !length $text);

    # Ampersand-encoding based entirely on Nat Irons's Amputator MT plugin:
    #   http://bumppo.net/projects/amputator/
    $text =~ s/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w+);)/&amp;/g;

    # Encode naked <'s
    $text =~ s{<(?![a-z/?\$!])}{&lt;}gi;

    # And >'s - added by Fletcher Penney
#   $text =~ s{>(?![a-z/?\$!])}{&gt;}gi;
#   Causes problems...

    # Remove encoding inside comments
    $text =~ s{
        (?<=<!--) # Begin comment
        (.*?)     # Anything inside
        (?=-->)   # End comments
    }{
        my $t = $1;
        $t =~ s/&amp;/&/g;
        $t =~ s/&lt;/</g;
        $t;
    }egsx;

    return $text;
}

sub _EncodeBackslashEscapes {
#
#   Parameter:  String.
#   Returns:    The string, with after processing the following backslash
#               escape sequences.
#
    my $self = shift;
    local $_ = shift;

    s! \\\\  !$g_escape_table{'\\'}!ogx;     # Must process escaped backslashes first.
    s! \\`   !$g_escape_table{'`'}!ogx;
    s! \\\*  !$g_escape_table{'*'}!ogx;
    s! \\_   !$g_escape_table{'_'}!ogx;
    s! \\\~  !$g_escape_table{'~'}!ogx;
    s! \\\^  !$g_escape_table{'^'}!ogx;
    s! \\\{  !$g_escape_table{'{'}!ogx;
    s! \\\}  !$g_escape_table{'}'}!ogx;
    s! \\\[  !$g_escape_table{'['}!ogx;
    s! \\\]  !$g_escape_table{']'}!ogx;
    s! \\\(  !$g_escape_table{'('}!ogx;
    s! \\\)  !$g_escape_table{')'}!ogx;
    s! \\>   !$g_escape_table{'>'}!ogx;
    s! \\\#  !$g_escape_table{'#'}!ogx;
    s! \\\+  !$g_escape_table{'+'}!ogx;
    s! \\\-  !$g_escape_table{'-'}!ogx;
    s! \\\.  !$g_escape_table{'.'}!ogx;
    s{ \\!  }{$g_escape_table{'!'}}ogx;

    return $_;
}

sub _DoAutoLinks {
    my ($self, $text) = @_;

    $text =~ s{<((https?|ftp):[^'">\s]+)>}{<a href="$1">$1</a>}gi;

    # Email addresses: <address@domain.foo>
    $text =~ s{
        <
        (?:mailto:)?
        (
            [-.\w\+]+
            \@
            [-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+
        )
        >
    }{
        $self->_EncodeEmailAddress( $self->_UnescapeSpecialChars($1) );
    }egix;

    return $text;
}

sub _EncodeEmailAddress {
#
#   Input: an email address, e.g. "foo@example.com"
#
#   Output: the email address as a mailto link, with each character
#       of the address encoded as either a decimal or hex entity, in
#       the hopes of foiling most address harvesting spam bots. E.g.:
#
#     <a href="&#x6D;&#97;&#105;&#108;&#x74;&#111;:&#102;&#111;&#111;&#64;&#101;
#       x&#x61;&#109;&#x70;&#108;&#x65;&#x2E;&#99;&#111;&#109;">&#102;&#111;&#111;
#       &#64;&#101;x&#x61;&#109;&#x70;&#108;&#x65;&#x2E;&#99;&#111;&#109;</a>
#
#   Based on a filter by Matthew Wickline, posted to the BBEdit-Talk
#   mailing list: <http://tinyurl.com/yu7ue>
#

    my ($self, $addr) = @_;

    my @encode = (
        sub { '&#' .                 ord(shift)   . ';' },
        sub { '&#x' . sprintf( "%X", ord(shift) ) . ';' },
        sub {                            shift          },
    );

    $addr = "mailto:" . $addr;

    $addr =~ s{(.)}{
        my $char = $1;
        if ( $char eq '@' ) {
            # this *must* be encoded. I insist.
            $char = $encode[int rand 1]->($char);
        }
        elsif ( $char ne ':' ) {
            # leave ':' alone (to spot mailto: later)
            my $r = rand;
            # roughly 10% raw, 45% hex, 45% dec
            $char = (
                $r > .9   ?  $encode[2]->($char)  :
                $r < .45  ?  $encode[1]->($char)  :
                             $encode[0]->($char)
            );
        }
        $char;
    }gex;

    $addr = qq{<a href="$addr">$addr</a>};
    $addr =~ s{">.+?:}{">}; # strip the mailto: from the visible part

    return $addr;
}

sub _UnescapeSpecialChars {
#
# Swap back in all the special characters we've hidden.
#
    my ($self, $text) = @_;

    while( my($char, $hash) = each(%g_escape_table) ) {
        $text =~ s/$hash/$char/g;
    }
    return $text;
}

sub _TokenizeHTML {
#
#   Parameter:  String containing HTML markup.
#   Returns:    Reference to an array of the tokens comprising the input
#               string. Each token is either a tag (possibly with nested,
#               tags contained therein, such as <a href="<MTFoo>">, or a
#               run of text between tags. Each element of the array is a
#               two-element array; the first is either 'tag' or 'text';
#               the second is the actual value.
#
#
#   Derived from the _tokenize() subroutine from Brad Choate's MTRegex plugin.
#       <http://www.bradchoate.com/past/mtregex.php>
#

    my ($self, $str) = @_;
    my $pos = 0;
    my $len = length $str;
    my @tokens;

    my $depth = 6;
    my $nested_tags = join('|', ('(?:<[a-z/!$](?:[^<>]') x $depth) . (')*>)' x  $depth);
    my $match = qr/(?s: <! ( -- .*? -- \s* )+ > ) |  # comment
                   (?s: <\? .*? \?> ) |              # processing instruction
                   $nested_tags/iox;                   # nested tags

    while ($str =~ m/($match)/og) {
        my $whole_tag = $1;
        my $sec_start = pos $str;
        my $tag_start = $sec_start - length $whole_tag;
        if ($pos < $tag_start) {
            push @tokens, ['text', substr($str, $pos, $tag_start - $pos)];
        }
        push @tokens, ['tag', $whole_tag];
        $pos = pos $str;
    }
    push @tokens, ['text', substr($str, $pos, $len - $pos)] if $pos < $len;
    \@tokens;
}

sub _Outdent {
#
# Remove one level of line-leading tabs or spaces
#
    my ($self, $text) = @_;

    $text =~ s/^(\t|[ ]{1,$self->{tab_width}})//gm;
    return $text;
}

sub _Detab {
#
# Cribbed from a post by Bart Lateur:
# <http://www.nntp.perl.org/group/perl.macperl.anyperl/154>
#
    my ($self, $text) = @_;

    # FIXME - Better anchor/regex would be quicker.

    # Original:
    #$text =~ s{(.*?)\t}{$1.(' ' x ($self->{tab_width} - length($1) % $self->{tab_width}))}ge;

    # Much swifter, but pretty hateful:
    do {} while ($text =~ s{^(.*?)\t}{$1.(' ' x ($self->{tab_width} - length($1) % $self->{tab_width}))}mge);
    return $text;
}

sub _ConvertCopyright {
    my ($self, $text) = @_;
    # Convert to an XML compatible form of copyright symbol

    $text =~ s/&copy;/&#xA9;/gi;

    return $text;
}

1;

__END__

=head1 NAME

Text::Markmoremown (markmod) - Convert MarkMoreDown syntax to HTML

=head1 SYNOPSIS

    use Text::Markmoredown 'markmod';
    my $html = markmod($text);

    use Text::Markmoredown 'markmod';
    my $html = markmod( $text, {
        empty_element_suffix => '>',
        tab_width => 2,
    } );

    use Text::Markmoredown;
    my $m = Text::Markmoredown->new;
    my $html = $m->markdown($text);

    use Text::Markmoredown;
    my $m = Text::Markmoredown->new(
        empty_element_suffix => '>',
        tab_width => 2,
    );
    my $html = $m->markdown( $text );

=head1 DESCRIPTION

MarkMoreDown (markmod) is a free MIT-licensed perl library for parsing and
converting a superset of Markdown. It is supports standard Markdown
(with some minor modifications) and various extensions that have inspired
by PHP Markdown Extra, MultiMarkdown, kramdown and etc.

=head1 SYNTAX

=head2 Headings

Headings from h1 through h6 are constructed with a # for each level:

    # h1 Heading
    ## h2 Heading
    ### h3 Heading
    #### h4 Heading
    ##### h5 Heading
    ###### h6 Heading

    <h1>h1 Heading</h1>
    <h2>h2 Heading</h2>
    <h3>h3 Heading</h3>
    <h4>h4 Heading</h4>
    <h5>h5 Heading</h5>
    <h6>h6 Heading</h6>

Alternatively, for H1 and H2, an underline-ish style:

    Alt-H1
    ======

    Alt-H2
    ------

    <h1>Alt-H1</h1>
    <h2>Alt-H2</h2>

B<difference to standard markdown>

optional labels, a : after #, = or -

    ## h2 #:head-label
    #### h4 ########:my-label

    <h2 id="head-label">h2</h2>
    <h4 id="my-label">h4</h4>

    Alt-h1
    ====== :my-label

    <h1 id="my-label">Alt-H1</h1>

=head2 Horizontal Rules

A horizontal rule for visually separating content is created by using three or
more asterisks, dashes or underscores (these may not be mixed on a line),
optionally separated by spaces, on an otherwise blank line. The first
asterisk, dash or underscore may optionally be indented up to three spaces.

    ***
    ---
    ___
    * * * * * * * * *
    --------
    ______________


    <hr>

=head2 Paragraphs and Line Breaks

paragraph is simply one or more consecutive lines of text, separated by one or
more blank lines. (A blank line is any line that looks like a blank line
— a line containing nothing but spaces or tabs is considered blank.) Normal
paragraphs should not be indented with spaces or tabs.

The implication of the “one or more consecutive lines of text” rule is that
Markdown supports “hard-wrapped” text paragraphs. This differs significantly
from most other text-to-HTML formatters (including Movable Type’s “Convert Line
Breaks” option) which translate every line break character in a paragraph into
a <br> tag.

When you do want to insert a <br> break tag using Markdown, you end a line with
two or more spaces, then type return.

    Lorem ipsum dolor sit amet, graecis denique ei vel, at duo primis mandamus.
    Et legere ocurreret pri, animal tacimates complectitur ad cum. Cu eum
    inermis inimicus efficiendi.⋅⋅
    Labore officiis his ex, soluta officiis
    concludaturque ei qui, vide sensibus vim ad.

    <p>
    Lorem ipsum dolor sit amet, graecis denique ei vel, at duo primis mandamus. Et legere ocurreret pri, animal tacimates complectitur ad cum. Cu eum inermis inimicus efficiendi.
    <br>
    Labore officiis his ex, soluta officiisconcludaturque ei qui, vide sensibus vim ad.
    </p>

B<difference to standard markdown>

=head3 >> Attribute List Definitions

{= .class #id style="..." dir="..." align="..." .... }

    Lorem ipsum dolor sit amet, graecis denique ei vel, at duo primis mandamus.
    Et legere ocurreret pri, animal tacimates complectitur ad cum. Cu eum
    inermis inimicus efficiendi.⋅⋅
    Labore officiis his ex, soluta officiis
    concludaturque ei qui, vide sensibus vim ad.
    {= .class #entry .more align="center" #body width="200px" }

    <p class="class more" id="entry body" align="left" width="200px">
    Lorem ipsum dolor sit amet, graecis denique ei vel, at duo primis mandamus. Et legere ocurreret pri, animal tacimates complectitur ad cum. Cu eum inermis inimicus efficiendi.
    <br>
    Labore officiis his ex, soluta officiisconcludaturque ei qui, vide sensibus vim ad.
    </p>

=head2 Emphasis

B<Bold>

For emphasizing a snippet of text with a heavier font-weight.

The following snippet of text is rendered as bold text.

    **rendered as bold text**

    <strong>rendered as bold text</strong>

B<Italics>

For emphasizing a snippet of text with italics.

    _rendered as italicized text_

    <em>rendered as italicized text</em>

B<Mark>

    mark element defines ==marked== or ==highlighted== text

    mark element defines <mar>marked</mark> or <mark>highlighted</mark> text

B<Inserted text>

    ins element defines ++inserted++ (added) text.

    ins element defines <ins>inserted</ins> (added) text.

B<Small>

    small element defines --smaller-- text

    small element defines <small>smaller</small> text

B<strikethrough, deleted text>

    ~~Strike through this text.~~

    <del>Strike through this text.</del>

B<Deleted/Inserted Text>

    ~~this is incorrect ~> this is correct~~

    <del>this is incorrect</del> <ins>this is correct</ins>

one space before and after ~> is optional

B<Superscript text>

    x^y + z^

    x<sup>y + z</sup>

B<Subscript text>

    text~index~

    text<sub>index</sub>

    C~6~H~12~O~6~

    C<sub>6</sub>H<sub>12</sub>O<sub>6</sub>

=head2 Lists

Markdown supports ordered (numbered) and unordered (bulleted) lists.

=head3 Unordered Lists

Unordered lists use asterisks, pluses, and hyphens — interchangably — as list
markers.

    + Lorem ipsum dolor sit amet
    + Consectetur adipiscing elit
    + Integer molestie lorem at massa
    + Facilisis in pretium nisl aliquet
    + Nulla volutpat aliquam velit
      - Phasellus iaculis neque
        * Purus sodales ultricies
        * Vestibulum laoreet porttitor sem
      - Ac tristique libero volutpat at
      + Faucibus porta lacus fringilla vel
      + Aenean sit amet erat nunc
      + Eget porttitor lorem

    <ul>
    <li>Lorem ipsum dolor sit amet</li>
    <li>Consectetur adipiscing elit</li>
    <li>Integer molestie lorem at massa</li>
    <li>Facilisis in pretium nisl aliquet</li>
    <li>Nulla volutpat aliquam velit
      <ul>
        <li>Phasellus iaculis neque</li>
          <ul>
            <li>Purus sodales ultricies</li>
            <li>Vestibulum laoreet porttitor sem</li>
          </ul>
        <li>Ac tristique libero volutpat at</li>
      </ul>
    </li>
    <li>Faucibus porta lacus fringilla vel</li>
    <li>Aenean sit amet erat nunc</li>
    <li>Eget porttitor lorem</li>
    </ul>

    + item
    - item
    * item

=head3 Ordered Lists

A list of items in which the order of items does explicitly matter.

    1. Lorem ipsum dolor sit amet
    2. Consectetur adipiscing elit
        1. item
            - unordered item
            - unordered item
        2. item
        3. item
    3. Integer molestie lorem at massa
    4. Facilisis in pretium nisl aliquet
    5. Nulla volutpat aliquam velit
    6. Faucibus porta lacus fringilla vel
    7. Aenean sit amet erat nunc
    8. Eget porttitor lorem

=head3  Definition Lists

MarkMoreDown has support for definition lists using the same syntax used in
PHP Markdown Extra. Specifically:

    Apple
    :   Pomaceous fruit of plants of the genus Malus in
        the family Rosaceae.
    :   An american computer company.

    Orange
    :   The fruit of an evergreen tree of the genus Citrus.

becomes:

    <dl>
    <dt>Apple</dt>
    <dd>Pomaceous fruit of plants of the genus Malus in
    the family Rosaceae.</dd>

    <dt>Orange</dt>
    <dd>The fruit of an evergreen tree of the genus Citrus.</dd>
    </dl>

=head3 separator

If you want to have one list directly after another one (both with the same
list type, i.e. ordered or unordered), you need to use an EOB marker to
separate the two:

    * List one

    ^

    * List two

=head2 BlockQuotes

Markdown uses email-style > characters for blockquoting. If you’re familiar
with quoting passages of text in an email message, then you know how to create
a blockquote in Markdown. It looks best if you hard wrap the text and put a >
before every line, Blockquotes can contain other Markdown elements, including
headers, lists, and code blocks

    > This is a blockquote . Lorem ipsum dolor sit amet,
    > consectetuer adipiscing elit. Aliquam hendrerit mi posuere lectus.
    > Vestibulum enim wisi, viverra nec, fringilla in, laoreet vitae, risus.
    >
    > This is a blockquote with two paragraphs. Lorem ipsum dolor sit amet,
    consectetuer adipiscing elit. Aliquam hendrerit mi posuere lectus.
    Vestibulum enim wisi, viverra nec, fringilla in, laoreet vitae, risus.
    > > This is nested blockquote.
    > ## This is a header.

    > 1.   This is the first list item.
    > 2.   This is the second list item.
    >
    > Here's some example code:
    >

B<separator>

    If you want to have one list directly after another one (both with the same
    list type, i.e. ordered or unordered), you need to use an EOB marker to
    separate the two:

=head2 Links

Markdown supports two style of links: inline and reference.

In both styles, the link text is delimited by [square brackets].

=head3 inline-style links

To create an inline link, use a set of regular parentheses immediately after
the link text’s closing square bracket. Inside the parentheses, put the URL
where you want the link to point, along with an optional title for the link,
surrounded in quotes. For example:

    This is [an example](http://kiavash.one/ "Title") inline link.

    [This link](http://kiavash.one/) has no title attribute.

If you’re referring to a local resource on the same server, you can use
relative paths:

    See my [About](/about/) page for details.

=head3 reference-style links

Reference-style links use a second set of square brackets, inside which you
place a label of your choosing to identify the link:

    This is [an example][id] reference-style link.

You can optionally use a space to separate the sets of brackets:

    This is [an example] [id] reference-style link.

Then, anywhere in the document, you define your link label like this, on a line by itself:

    [id]: http://kiavash.one/  "Optional Title Here"

The implicit link name shortcut allows you to omit the name of the link, in
which case the link text itself is used as the name. Just use an empty set of
square brackets

    this is a link [kiavash][]

    [kiavash]: http://kiavash.one

=head3 Link Attributes

you can set the attributes on certain elements using an attribute block. put
the special attribute block {} immediately after the parenthesis or brackets
containing the address.

    This is [an example][id]{.class1 .class2 #id1 style="..." #id3 other-attributes}

    [This link](http://kiavash.one/){.class1 .class2 #id1 style="..." #id3 other-attributes}

B<dont use spaces in attributes.>

wrong

    style="border: 1px; width: 150px"

correct

    style="border:1px;width:150px"

=head2 Images

Admittedly, it’s fairly difficult to devise a “natural” syntax for placing
images into a plain text document format.

Markdown uses an image syntax that is intended to resemble the syntax for links,
allowing for two styles: inline and reference.

=head3 Inline Images

Inline image syntax looks like this:

    ![Alt text](/path/to/img.jpg)

    ![Alt text](/path/to/img.jpg "Optional title")

=head3 Reference-style Image

Reference-style image syntax looks like this:

    ![Alt text][id]

Where “id” is the name of a defined image reference. Image references are
defined using syntax identical to link references:

    [id]: url/to/image  "Optional title attribute"

=head3 Image Attributes

you can set the attributes on certain elements using an attribute block. put
the special attribute block {} immediately after the parenthesis or brackets
containing the address.

    ![Alt text](/path/to/img.jpg){.class1 .class2 #id1 style="..." #id3 width="100px" height="100px"}

    ![Alt text][id]{.class1 .class2 #id1 style="border:2px;max-width:100%" #id3 other-attributes}

B<dont use spaces in attributes.>

wrong

    style="border: 1px; width: 150px"

correct

    style="border:1px;width:150px"

=head2 Codes

=head3 Inline code

To indicate a span of code, wrap it with backtick quotes (`). Unlike a
pre-formatted code block, a code span indicates code within a normal paragraph.
For example:

    Use the `printf()` function.

will produce:

    Use the <code>printf()</code> function.


=head3 Code Blocks

Pre-formatted code blocks are used for writing about programming or markup
source code. Rather than forming normal paragraphs, the lines of a code block
are interpreted literally. Markdown wraps a code block in both <pre> and <code>
tags.

To produce a code block in Markdown, simply indent every line of the block by
at least 4 spaces or 1 tab. For example, given this input:

    This is a normal paragraph:

        This is a code block.

Markdown will generate:

    <p>This is a normal paragraph:</p>

    <pre><code>This is a code block.
    </code></pre>

One level of indentation — 4 spaces or 1 tab — is removed from each line of the
code block. For example, this:

    Here is an example of AppleScript:

        tell application "Foo"
            beep
        end tell

will turn into:

    <p>Here is an example of AppleScript:</p>

    <pre><code>tell application "Foo"
        beep
        end tell
    </code></pre>

=head3 separator

you can separate code blocks with ^

        code block1
        code block1

    ^

        code block2
        code block2

=head3 Block code "fences"

Use "fences" ``` to block in multiple lines of code.

    ```
    codes...
    ```

or

    ``` perl
    code...
    code...
    code...
    ```

    <pre><code class="language-perl">
        code...
        code...
        code...
    </code></pre>

and

    ``` :class-name
    some codes...
    ```

    <pre><code class="class-name">
    some codes...
    </code></pre>

=head2 Tables

    |              | Grouping                    ||
    | First Header | Second Header | Third Header |
    | ------------ | :-----------: | -----------: |
    | Content      | *Long Cell*                 ||
    | Content      | **Cell**      | Cell         |
    | New section  | More          | Data         |

=head2 Maths

=head3 Math block

    $$
    MathML
    $$

or

    \\[
    MathML
    \\]

=head3 inline Maths

    $ Math formula $

or

    \\(
    formula
    \\)

=head3 Footnotes

=head3 Citations

=head1 OPTIONS

MarkMoreDown supports a number of options to it's processor which control the
behaviour of the output document.

These options can be supplied to the constructor, on in a hash with the
individual calls to the markdown method.See the synopsis for examples of both
of the above styles.

The options for the processor are:

=over

=item empty element suffix

This option can be used to generate normal HTML output. By default, it is '>',
which is HTML, change to ' />' for xHTML.

=item img_ids

Controls if <img> tags generated have an id attribute. Defaults to true.
Turn off for compatibility with the original markdown.

=item heading_ids

Controls if <hX> tags generated have an id attribute. Defaults to true.
Turn off for compatibility with the original markdown.

=item tab_width

Controls indent width in the generated markup, defaults to 4

=item disable_tables

If true, this disables the MarkMoreDown table handling.

=item disable_footnotes

If true, this disables the MarkMoreDown footnotes handling.

=item disable_bibliography

If true, this disables the MarkMoreDown bibliography/citation handling.

=item disable_definition_lists

If true, this disables the MarkMoreDown definition list handling.

=back

=head1 METHODS

=head2 new

A simple constructor, see the SYNTAX and OPTIONS sections for more information.

=head2 markmod

The main function as far as the outside world is concerned. See the SYNOPSIS
for details on use.

=head1 AUTHOR

    John Gruber
    http://daringfireball.net/

    PHP port and other contributions by Michel Fortin
    http://michelf.com/

    MultiMarkdown by Fletcher Penney
    http://fletcher.freeshell.org/

    kramdown by Thomas Leitner
    http://kramdown.gettalong.org/

    CPAN Module Text::MultiMarkdown by Tomas Doran
    http://www.bobtfish.net/

    MarkMoreDown by Kiavash Mazi
    http://kiavash.one

=head1 THIS DISTRIBUTION

Please note that this distribution is a fork of Fletcher Penny's MarkMoreDown project,
and it *is not* in any way blessed by him.

Whilst this code aims to be compatible with the original MarkMoreDown (and incorporates
and passes the MarkMoreDown test suite) whilst fixing a number of bugs in the original -
there may be differences between the behaviour of this module and MarkMoreDown. If you find
any differences where you believe Text::MarkMoreDown behaves contrary to the MarkMoreDown spec,
please report them as bugs.

=head1 SOURCE CODE

You can find the source code repository for L<Text::Markmdown> and L<Text::Markmoredown>
on GitHub at <http://github.com/bobtfish/text-markdown> and
<https://github.com/kiamazi/markmoredown>.

=head1 COPYRIGHT AND LICENSE

Original Code Copyright (c) 2003-2004 John Gruber
<http://daringfireball.net/>
All rights reserved.

MultiMarkdown changes Copyright (c) 2005-2006 Fletcher T. Penney
<http://fletcher.freeshell.org/>
All rights reserved.

Text::MarkMoreDown changes Copyright (c) 2018 Kiavash Mazi
<http://kiavash.one>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

* Neither the name "Markdown" nor the names of its contributors may
  be used to endorse or promote products derived from this software
  without specific prior written permission.

This software is provided by the copyright holders and contributors "as
is" and any express or implied warranties, including, but not limited
to, the implied warranties of merchantability and fitness for a
particular purpose are disclaimed. In no event shall the copyright owner
or contributors be liable for any direct, indirect, incidental, special,
exemplary, or consequential damages (including, but not limited to,
procurement of substitute goods or services; loss of use, data, or
profits; or business interruption) however caused and on any theory of
liability, whether in contract, strict liability, or tort (including
negligence or otherwise) arising in any way out of the use of this
software, even if advised of the possibility of such damage.

=cut
