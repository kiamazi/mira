package Mira;

use strict;
use warnings;
use 5.012;
our $VERSION = '00.07.50';


1;
__END__

=pod

=encoding utf8

=head1 NAME

mira - static site generator

=head1 VERSION

This document describes L<mira> version B<00.07.48>.


=head1 Mira

integrated content management framework for create multiple websites.

A publishing tools for creat multiple static web sites

LL<https://metacpan.org/release/Mira>, Mira comes with a command-line application called C<mira> which you can use to create static websites.

 $ cpanm Mira # Install
 $ mira init                                  # Initialize current directory with new site
 $ mira new -t "post_title" -f "floor_name"   # creat new post
 $ mira build                                 # Build contents
 $ mira view                                  # serve locally at http://localhost:5000

B<Features>

=over

=item * Written in perl, available as a command line utility after installing.

=item * Content is written in many MarkUP languages.

=item * Layouts are developed using TT2 from the Template-toolkit templating engine.

=item * Configuration files and attributes are encoded with YAML.

=item * mira is a building, each directory in content folder is a floor, each floor is a separated site.

=item * each subdirectory in floors which start with _ is a static folder

=item * mira have a global config.yml in root

=item * each floor can have a config file in config directory: config/floor_name.yml

=back

=head1 Getting Started

The following sections show you how to install, upgrade, and downgrade the version of Mira you have, as well as how to use the C<mira> command-line utility and work with the directory structure it depends on.

=head2 Install

Install Mira in seconds:

 $ cpanm Mira

Then, create a new site, build it, and view it locally like so:

 $ mkdir new-site && cd new-site
 $ mira init
 $ mira -t "new post" -f blog
 $ Mira build
 $ Mira view

After that, browse to LL<http://localhost:5000> to see your site.

To modify the content, look at C<content/blog/yyyy-mm-dd-new_post.md>. you can change your content file name and extension, for wxample: C<content/blog/my_first_test_new_post.custom>

To modify the layout, edit C<template/default_theme/index.tt2>.

=head3 Upgrade

Find out which version of Mira you have, by using the C<-v> option:

 $ mira -v

You can compare this with the latest version from CPAN like this:

 $ cpan -D Mira

 ...
 ...
 Installed: 0.07.42
 CPAN:      0.07.47  Not up to date
 ...
 ...

In this example, you can see there is a newer version available. Upgrade like this:

 $ cpan Mira

Stable releases are available on CPAN, but development happens at LL<https://github.com/kiamazi/mira>. If you like living on the edge, install from the latest development tip like this:

 $ cpanm git://github.com/kiamazi/mira.git

=head3 Downgrade

If you want to install an older version of Mira, first find the link on
LL<http://backpan.perl.org/authors/id/K/KI/KIAVASH/mira/>. Then, install like
this (e.g. v0.07.39):

 $ cpanm http://backpan.perl.org/authors/id/K/KI/KIAVASH/mira/Mira-00.07.39.tar.gz

If you want, you can also install from source. To do that, you just need to download and unpack the desired release from LL<http://backpan.perl.org/authors/id/K/KI/KIAVASH/mira/>, or clone the repository from Github. Then, do this:

 $ perl Makefile.PL
 $ make
 $ make test
 $ make install

=head2 Usage

When you install the C<Mira> Perl module, an executable named C<mira> will be available to you in your terminal window.
You can use this executable in a number of ways. The following sections show you how.

=head3 Init

The C<mira init> command initializes a new site. Note that the site will be initialized in the current directory. Therefore, it's usually best to create a blank directory that can be used for this purpose. A description of the resulting directory structure is available in the
L<#directory-structure> section.

 # Initialize the current directory with a fresh skeleton of a site
 $ mira init

=head3 New

After the site has been initialized, create new post in blog floor using the C<mira new> command.

 $mira new -t "new post" -f blog

=head3 Build

After the site has been initialized, build it using the C<mira build> command. Mira takes care of reading the source files, combining them with the layout template(s), and saving the result in the C<public> directory.

 # Build the site
 $ mira build

=head3 View

The C<Mira view> command serves the contents of the C<public> directory using Mira's built-in webserver.

 # Serve the site locally at http://localhost:8000
 $ mira view

If you want to use a different port number (e.g. 9000) or different host address (e.g. 127.0.0.24), specifiy it using the I<-p> and I<-o> options:

 # Serve the site locally at http://localhost:9000
 $ mira view -p 9000 -o 127.0.0.24

=head2 Directory Structure

After running the L<#init> command, the following directory structure will be created:

 │
 ├── config
 ├── config.yml
 ├── content
 ├── public
 ├── statics
 ├── structure
 └── template

Here is a description of each file:

B<config.yml>

The configuration file is a LL<http://www.yaml.org/> file that specifies key configuration elements for your static websites. The default configuration file is as follows:

 # Mira configuration file
 ---
 title : My Sites
 ...
 ...
 ...

If you want to use another output directory, you may specify it in this file. For instance:

 # Mira configuration file
 ---
 title : My Site
 template: layout_name
 publishDIR: public
 output_extension: html    # output file extension
 default_extension: md     # new file extension

each floor can have them config or use config.yml by default, if you need a config file for blog, you can crate C<config/blog.yml>. publishDIR is only available in config.yml, but other config fields can use in general and public configs.

There are a few definitions that affect the way that Mira behaves. Those are defined in the L<#configuration> section. Those and any others that you choose to specify become available in the layout templates under the C<SITE> or C<MAIN> namespace. For instance, C<title> is available in templates like this:

 {{ SITE.name }}   # floor title saved in config/floor_name.yml
 {{ MAIN.title }}  # main title saved in config.yml

B<content>

all directories in content is a separated site. each file in this directories is a content:

defaut format for content file is like this:

 ---
 utid: 20170214184439
 date: 2017-02-14 18:44:39
 title: this is post title
 ---

 Hello world.

There are a few things to note about this file:

=over

=item 1. There is a YAML configuration block at the start of the file.

=item 2. the C<utid> configuration is master key of posts, all posts will be define and sort by this field.

=item 3. The C<title> configuration is the name of the post/page.

=item 4. All of the configurations may be used in the corresponding layout file.

<!-- Example use of "title" in a layout file -->
{{ post.title }}

=back

B<structure>

if you need custom post header for each floor, you can make a structure file in this folder:

structure/blog

 categories:
  -
 tags:
  -
 post_image:

B<template>

Layout files are processed using the TT2 from the Template-Toolkit template system. each folder in template is a separated template.

each template need this layouts:

 main.tt2
 index.tt2
 post.tt2
 archive.tt2
 atom.tt2

B<public>

The output file that is created is a mix of the input file and the template that is specified by the config file.

=head1 Configuration

Mira allows you to create static websites in just about any way that you want to. The project configuration files (C<config.yml> and C<config/floor_name.yml>) allows you to specify special instructions to Mira and also to guide the process of rendering the site using the source files (C<content/>) and the layout templates (C<template/layout_name>).

Variables specified in C<config.yml> and C<config> directory, are done using YAML.

=over

=item * B<description>

=item * B<ur>l

=item * B<root>

=item * B<static>

=item * B<imageurl>

=item * B<publishDIR>

default is 'public'

=item * B<post_num>

number or 'all'

=item * B<archive_post_num>

number or 'all'

=item * B<feed_post_num>

number or 'all'

=item * B<post_sort>

can set 'reverse'

=item * B<feed_output>

default is 'feed.xml'

=item * B<feed_template>

default is 'atom.tt2'

=item * B<default_floor>

if in new command dont use -f switch, mira use this field value for floor name

=item * B<permalink>

/:year/:month/:day/:FIELD_NAME/every_thing_else/:title .html or .php or .xhtnl or any extension you like

A full list of pattern options are as follows:

=item * B<default_markup>

=over

=item * markdown -or- md

=item * mmd   (mira markdown parser based on multimarkdown 2.0.b6)

=item * bbcode

=item * textile

=item * text -or- txt   just add C<< E<lt>brE<gt> >> in endlines

=item * html

=back

=item * B<default_extension>

default extension for new content files, default is md

=item * B<output_extension>

default extension for output files, default is html

=item * B<time_zone>

=item * B<t_start_tag>

template tag for use in theme, default is {{

=item * B<t_end_tag>

template tag for use in theme, default is }}

=item * B<t_outline_tag>

=item * B<feed_output>

default is feed.xml

=item * B<feed_template>

default is atom.tt2

=item * B<lists>

the fields you want make archive

=item * B<namespace> change lists static address

veryverylongarchivename : vlan      # /blog/tags/veryverylongarchivename  >   /blog/tags/vlan

=back

sample:

 title: my site
 url: http://myaddress.net/blog
 root: /blog

 lists:
  - date
  - tags

 links :
     Feed : http://feeds.feedburner.com/myfeed
     Amazon : http://amazon.com/author/name
     Github : http://github.com/name
     LinkedIn : http://linkedin.com/in/name
     Twitter : https://twitter.com/name

 socials:
  -  name: twitter
     url: https://twitter.com/UserName
     desc: Follow me on twitter

  -  name: github
     url: https://github.com/UserName
     desc: Fork me on twitter

  -  name: facebook
     url: https://facebook.com/UserName
     desc: Follow me on facebook

Any variable specified in C<configs> can be used in a template. MAIN for config.yml  and  SITE for config directory

 {{ SITE.title }}

URL can be used like this:

 <a href="{{ MAIN.url }}">{{ MAIN.title }}</a>

The links (key/value pairs) can be listed like this:

 {{ FOREACHEACH link in SITE.links }}
     <a href="{{ link.value }}">{{ link.key }}</a><br />
 {{ END }}

All of the items in the C<social> array can be shown like this:

 {{ FOREACHEACH social in SITE.socials }}
   <a href="{{ social.url }}">{{ social.name }} : {{ social.desc }}</a>
 {{- END }}

See the official LL<http://yaml.org/> specification.

=head1 content

content files in Mira are have 2 section, header and body.

 ---
 utid:
 title:
 ---
 content body

headers must contain LL<http://yaml.org/>.
The YAML at the beginning of the content files is denoted by leading and trailing lines that each contain a sequence of three dashes. Example:

 ---
 utid: 123456
 title: Post Title
 ---

 Here is the text of the post.

Variable definitions in headers that carry special meaning are as follows:

=over

=item * utid

master key of posts, dont edit it

=item * date

=item * title

=item * _index

change value for :title, if empty, title will be used for output name

=item * _permalink

defines the URL path for the output file just for this post. This may also be specified in C<config> as well.

=item * _type

default is post, but can set 'page'

=item * _markup

change body markup language just for this post

=item * selective personal fields like categories, tags, keywords, author and ...

=back

=head1 template

Layout templates in Mira are based on a superset of the LL<http://template-toolkit.org/> v2 (TT2).
Although both Mira and TemplateToolkit are both written in Perl, you do not need to know Perl in order to use them.

Layout templates include a series of directives. Directives can be used to print the contents of a variable, or perform more sophisticated computation such as if/then/else, foreach, or case statements. Directives are surrounded by matched pairs of hard brackets and percent signs. Here is an example of printing a variable called C<SITE.title>:

 {{ site.name }}

When printing variables, you may also use filters to transform the variable or print information about it. For instance, you can convert a variable name to all uppercase letters using the C<upper> filter. Example:

 {{ SITE.title | upper }}

Another class of "logic" directives are used in a similar fashion. Here is an example of a for statement that loops through each C<social> in C<SITE.social>. For each iteration of the loop, print the contents of C<social.name>:

 {{ FOREACHEACH social in SITE.socials }}
   {{ social.name }}
 {{ END }}

The following sections show how to use directives in more depth.

=head2 Variables

This section describes how to use variables, literals, and expressions in Mira.

Variables are bits of text or numbers that are defined in the project configuration file or in the source files that can be used in templates. Here is an example of printing the contents of C<post.title>:

 {{ post.title }}

In Mira, there are two top-level variables (think of them as namespaces), which are C<SITE>-C<MAIN> and C<POSTS>. All C<SITE> variables are defined in C<config/floor_name.yml>, and C<MAIN> variables are defined in C<config.yml> and are available in layouts as C<{{ SITE.* }}> and C<{{ MAIN.* }}>. All page variables (defined at the beginning of source files) are available in
layouts as C<{{FOREACH post in POSTS}}{{ posts.* }}{{ END }}> for index and archives and C<{{ post.* }}> for post.tt2.

Example C<config/blog.yml>:

 title: main site title

Example C<content/blog/sample_post.md>:

 ---
 utid: 123456
 title: The title of my post
 ---
 less body
 <!-- more -->
 The body of my post.

Example C<template/my_layout/post.tt2>:

 <html>
 <head>
     <title>{{ post.title }} - {{ SITE.title }}</title>
 </head>
 <body>
     <h1>{{ post.title }}</h1>
     <p>{{ post.body.more }}</p>
 </body>
 </html>

This would produce the following:

 <html>
 <head>
     <title>The title of my post - site title</title>
 </head>
 <body>
     <h1>The title of my post</h1>
     <p>less body</p>
     <p>The body of my post.</p>
 </body>
 </html>

Variables can also be defined within a template file. For example:

 {{ a = 42 }}{{ a }}
 {{ b = "Hello" }}{{ b }}

Result:

 42
 Hello

It's also possible to create arrays:

 {{ a = [1, 2, 3, 4, 5] }}
 {{ a.1 }}
 {{ a | length }}

Result:

 2
 5

And associative arrays (hashes):

 {{ link = {name => 'ma name', 'url' => 'http://myaddress.com/'} }}
 <a href="{{ link.url }}">{{ link.name }}</a>

Result:

 <a href="http://myaddress.com/">my name</a>

I<Literals>

The following are the types of literals (numbers and strings) allowed in
layouts:

 {{ 23423 }}          Prints an integer
 {{ 3.14159 }}        Prints a number
 {{ pi = 3.14159 }}   Sets the value of the variable
 {{ 3.13159.length }} Prints 7 (the string length of the number)

I<Expressions>

Expressions are one or more variables or literals joined together with operators. An expression can be used anywhere a variable can be used with the exception of the left-hand side of a variable assignment directive or a filename for one of the C<process>, C<include>, C<wrapper>, or C<insert>
directives.

Examples:

 {{ 1 + 2 }}       Prints 3
 {{ 1 + 2 * 3 }}   Prints 7
 {{ (1 + 2) * 3 }} Prints 9

 {{ x = 2 }}       Assignments don't return anything
 {{ (x = 2) }}     Unless they are in parens. Prints 2
 {{ y = 3 }}
 {{ x * (y - 1) }} Prints 4

For a full listing of operators, see
LL<http://template-toolkit.org>.

=head2 Conditionals

Conditional statements are possible in Mira. A variety of options exist, including C<if/else>, C<unless>, and C<switch/case>, which are defined next.

=head3 IF/ELSE

C<IF> statements are used for controlling the flow of execution through a layout template. C<IF> statements take an expression. If true, the proceeding block is executed. If not, an C<ELSIF> block is executed (if it exists). Finally, an C<ELSE> block (if it exists) is executed if neither the C<IF> or the C<ELSIF> block is true. Example:

Here is an if/else example:

 {{ IF post.category == "books" }}
     Category: Books
 {{ ELSIF post.category == "movies" }}
     Category: Movies
 {{ ELSE }}
     Category: Unknown
 {{ END }}

For brevity, C<IF> statements may also be used as post-operative directives.
Example:

 {{ "Category: Books" IF post.category == "books" }}

=head3 UNLESS

Same as C<IF> statements, but the condition is reversed. The following block is only evaluated if the expression is I<not> true.

 {{ UNLESS post.category == "books" }}
     Category: (Not) Books
 {{ END }}

C<Unless> directives can also be used as post-operative directives. Example:

 {{ "Category: (Not) Books" UNLESS post.category == "books" }}

=head3 Switch/Case

Switch statements are allowed in Mira as well. Usage is best described with an example:

 {{ SWITCH post.category }}
     {{ case "books"  }} Category: Books
     {{ case "movies" }} Category: Movies
     {{ case default  }} Category: Unknown
 {{ END }}

=head2 Iteration

Iterative (looping) constructs are also available in Mira. Options include C<foreach>, and C<while>. Additionally, a C<loop> variable is provided to allow you to see information about the current loop.

=head3 FOREACH

C<Foreach> statements allow you to iterate over the contents of an array. If the variable is not already an array, it is automatically converted to an array for you. Example:

 {{ FOREACHEACH link IN SITE.blogroll }}
     The link is {{ link }}
 {{ END }}

You can also use C<=> in place of C<in>:

 {{ FOREACHEACH link = site.blogroll }}
     The link is {{ link }}
 {{ END }}

The C<foreach> statement also works on hashes:

 {{ FOREACHEACH [{a => 1}, {a => 2}] }}
     Key a = {{ a }}
 {{~ END }}

Result:

     Key a = 1
     Key a = 2

During a C<foreach> loop, a special variable called C<loop> is available and provides
the following information:

Variable         | Definition
-----------------|-------------------------------------------------------------
C<loop.index>     | The current index
C<loop.max>       | The max index of the list
C<loop.size>      | The number of items in the list
C<loop.count>     | Index + 1
C<loop.number>    | Index + 1
C<loop.first>     | True if on the first item
C<loop.last>      | True if on the last item
C<loop.next>      | Return the next item in the list
C<loop.prev>      | Return the previous item in the list
C<loop.odd>       | Return 1 if the current count is odd, 0 otherwise
C<loop.even>      | Return 1 if the current count is even, 0 otherwise
C<loop.parity>    | Return "odd" if the current count is odd, "even" otherwise

Example:

 {{ FOREACHEACH [1 .. 3] }}
     {{ loop.count }}/{{ loop.size }}
 {{ END }}

Result:

 1/3
 2/3
 3/3

Additinoally, C<break/last> and C<next> directives may be used in loops. C<Break> is an alias for C<last> and exits the loop. C<Next> skips the remainder of the current loop and begins the next iteration in the loop. Example:

 {{ FOREACHEACH [1 .. 3] }}
     {{ IF loop.count == 2 }}{{ BREAK }}{{ END }}
     {{ loop.count }}/{{ loop.size }}
 {{ END }}

Result:

 1/3

Example:

 {{ FOREACH [1 .. 3] }}
     {{ IF loop.count == 2 }}{{ NEXT }}{{ END }}
     {{ loop.count }}/{{ loop.size }}
 {{ END }}

Result:

 1/3
 3/3

=head3 While

The C<while> directive will process a block of code while a condition continues
to be true. Example:

 {{ i = 0 }}
 {{ while i < 3 }}
     {{ i = i + 1 }}
     i = {{ i }}
 {{ END }}
 #>

Result:

 i = 1
 i = 2
 i = 3

As with C<foreach> statements, C<break/last> and C<next> statements are also available.

=head2 BLOCK

C<Block> directives allow you to save a block of text under a name for later use in an C<include> directive. Blocks may be placed anywhere within the template being processed. Example:

 {{ BLOCK foo }}Some text{{ END }}
 {{ INCLUDE foo }}

=head2 Includes

An C<include> directive parses the contents of a file or C<block> and inserts them into the template. Variables that are defined or modified within the included bits are discarded after the include occurs. Example:

 {{ INCLUDE "path/to/template.tt2" }}

 {{ file = "path/to/template.html" }}
 {{ INCLUDE $file }}

 {{ BLOCK foo }}This is foo{{ END }}
 {{ INCLUDE foo }}

Arguments may also be passed to the template:

 {{ INCLUDE "path/to/template.tt2" a = "An arg" b = "Another arg" }}

Multiple filenames can be passed by separating them with a plus, a space, or commas. Any supplied arguments will be used on all templates. Example:

 {{ INCLUDE "path/to/template1.tt2",
            "path/to/template2.tt2" a = "An arg" b = "Another arg" }}

=head3 Date

The Date plugin provides an easy way to generate formatted time and date strings by delegating to the POSIX strftime() routine.

The plugin can be loaded via the C<use> directive.

 {{ USE date }}

This creates a plugin object with the default name of C<date>. An alternate name can be specified like this:

 {{ USE myname = date }}

The plugin provides the format() method which accepts a time value, a format string and a locale name. All of these parameters are optional with the current system time, default format ('%H:%M:%S %d-%b-%Y') and current locale being used respectively, if undefined. Default values for the time, format and/or locale may be specified as named parameters in the use directive.

 {{ USE date(format = '%a %d-%b-%Y', locale = 'fr_FR') }}

When called without any parameters, the format() method returns a string representing the current system time, formatted by strftime() according to the default format and for the default locale (which may not be the current one, if locale is set in the use directive).

 {{ date.format }}

The plugin allows a time/date to be specified as seconds since the epoch, as is returned by time().

 File last modified: {{ date.format(filemod_time) }}

The time/date can also be specified as a string of the form C<h:m:s d/m/y> or C<y/m/d h:m:s>. Any of the characters C<:> C</> C<-> or space may be used to delimit fields.

 {{ USE day = date(format => '%A', locale => 'en_GB') }}
 {{ day.format('4:20:00 9-13-2000') }}

Output:

 Tuesday

A format string can also be passed to the format() method, and a locale specification may follow that.

 {{ date.format(filemod, '%d-%b-%Y') }}
 {{ date.format(filemod, '%d-%b-%Y', 'en_GB') }}

A fourth parameter allows you to force output in GMT, in the case of seconds-since-the-epoch input:

 {{ date.format(filemod, '%d-%b-%Y', 'en_GB', 1) }}

Note that in this case, if the local time is not GMT, then also specifying '%Z' (time zone) in the format parameter will lead to an extremely misleading result.

Any or all of these parameters may be named. Positional parameters should always be in the order ($time, $format, $locale).

 {{ date.format(format => '%H:%M:%S') }}
 {{ date.format(time => filemod, format => '%H:%M:%S') }}
 {{ date.format(mytime, format => '%H:%M:%S') }}
 {{ date.format(mytime, format => '%H:%M:%S', locale => 'fr_FR') }}
 {{ date.format(mytime, format => '%H:%M:%S', gmt => 1) }}
 ...etc...

The now() method returns the current system time in seconds since the epoch.

 {{ date.format(date.now, '%A') }}

The calc() method can be used to create an interface to the Date::Calc module (if installed on your system).

 {{ calc = date.calc }}
 {{ calc.Monday_of_Week(22, 2001).join('/') }}

The manip() method can be used to create an interface to the Date::Manip module (if installed on your system).

 {{ manip = date.manip }}
 {{ manip.UnixDate("Noon Yesterday","%Y %b %d %H:%M") }}

=head2 Chomping

When using directives in templates, it can help to add whitespace around the directives to make them more readable. However, adding this whitespace can make the resulting output unreadable. To help with this, special uses of the C<+>, C<->, C<=>, and C<~> characters can be used to pre- and post-chomp the whitespace as follows:

=head4 {{+ Chomp None +}}

Don't do any chomping.

 Quick.

 {{+ "Brown." +}}

 Fox.

Result:

 Quick.

 Brown.

 Fox.

=head4 {{- Chomp One -}}

Delete any whitespace up to the adjacent newline.

 Quick.

 {{- "Brown." -}}

 Fox.

Result:

 Quick.
 Brown.
 Fox.

=head4 {{~ Chomp Greedy ~}}

Remove all adjacent whitespace.

 Quick.

 {{~ "Brown." ~}}

 Fox.

Result:

 Quick.Brown.Fox.

=head2 Github Pages

Github Pages is a free service that allows you to publish a static website for free. By pushing your changes to a git repository, your website will be automatically available on github.io. Here are the steps:

=over

=item 1. First, if you don’t have an account already, you should sign up for a LLL<http://github.com/>.

=item 2. Next, create a new repository named C<< E<lt>usernameE<gt>.github.io >> where you should replace C<< E<lt>usernameE<gt> >> with your actual Github username.

=item 3. After that, push the contents of your C<_output> directory to the new github repo. Steps:

   $ cd public
   $ git init
   $ git remote add origin https://github.com/<username>/<username>.github.io.git
   $ git add *
   $ git commit -m"Initial revision"
   $ git push

=item 4. Wait a few minutes. Then, find your new website on github.io at the following
address: C<< http://E<lt>usernameE<gt>.github.io >>.

=back

=head1 Author

Mira was written by Kiavash Mazi
LL<mailto:kiavash@cpan.org>.

=head1 License and Copyright

mira is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see LL<http://www.gnu.org/licenses/>.

=cut
