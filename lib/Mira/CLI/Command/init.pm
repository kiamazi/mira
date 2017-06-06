package Mira::CLI::Command::init;
$Mira::CLI::Command::init::VERSION = '00.07.49';

use strict;
use warnings;

use App::Cmd::Setup -command;

use 5.012;

use Cwd;
use File::Spec;
use File::Spec::Functions;
use File::Copy;
use File::Copy::Recursive qw(dircopy);
use File::Path qw(make_path);
use File::ShareDir ':ALL';

use utf8;
binmode STDOUT, ":utf8";



my $cwd = cwd;

sub abstract { 'mira structure generator' }

sub description { 'site generator script for Mira static site generator' }

sub opt_spec {
    return (
        [ 'directory|d=s', 'application path (default: current directory)', { default => $cwd } ],
        [ 'help|h',     'this help' ],
    );
}

sub validate_args {
  my ($self, $opt, $args) = @_;
  my $path = $opt->{directory};
  -d $path or $self->usage_error("directory '$path' does not exist");
}

sub execute {
  my ($self, $opt, $args) = @_;
  my $pensource = $opt->{directory};

  {
my $user = $ENV{'USER'} ? $ENV{'USER'} : 'YOUR_USER_NAME';
  my $config_file = <<"EOCF";

#general 'mira' config, you can make config files for any floor in /config/FLOOR_NAME.yml

## Site settings
title: Your Site Tilte
description: Description of your site

author: $user
email: your-email\@domain.com

timezone: +00:00

# the base hostname & protocol for your site
url: http://localhost:80
root: /
static: /static
imageurl: /static/img

## default post permanent link
permalink: :year/:month/:day/:title/


default_markup: markdown

## number of posts will be show in main index page
post_num: 5

## number of posts will be show in archives index page
archive_post_num: 10

## if create new entry without --floor switch with 'mira new', mira use this field
default_floor: blog


## template path root is /template
## if you want use a custom template for examle in /template/Custom_Template_Folde_Name
#> template: Custom_Template_Folde_Name
template: default-theme

# default archive fields, like category, tag and ...
# use for floors which haven't /config/FLOOR.yml or haven't filled or empty lists
lists:
  - date
  - categories
  - tags

#namespace:
#  veryverylongarchivename : vlan
#  learnsections: learn
#  mybooksButWithALongname: book
#  aboutThisSite: about
#  myPersonalDailyDiary: personal
#  terminalCommandLearning: terminal

social:
 -  icon: twitter
    name: twitter
    url: https://twitter.com/Twitter_UserName
    desc: Follow me on twitter
    share_url: http://twitter.com/share
    share_title: ?text=
    share_link: "&amp;url="

 -  icon: github
    name: github
    url: https://github.com/GitHub_UserName
    desc: Fork me on github
    share_url:
    share_title:
    share_link:

 -  icon: instagram
    name: instagram
    url: https://instagram.com/NAME
    desc: Follow me
    share_url:
    share_title:
    share_link:

 -  icon: facebook-square
    name: facebook
    url: https://facebook.com/NAME
    desc: Follow me
    share_url:
    share_title:
    share_link:

EOCF

  #make_path catdir($cwd,"make_test","conf") unless (-d "$cwd/make_test/conf/config.yml");
  my $file = catfile($pensource, "config.yml");
  open my $fh, '>:encoding(UTF-8)', $file || die;
  print $fh $config_file;
  close $fh;
  }

  make_path catdir($pensource,"content");
  make_path catdir($pensource,"content","blog");
  make_path catdir($pensource,"config");

  my $sharedir = dist_dir('Mira');

  dircopy(
      catdir($sharedir,"template")
      ,
      catdir($pensource,"template")
    ) or die $!;

  dircopy(
      catdir($sharedir,"structure")
      ,
      catdir($pensource,"structure")
    ) or die $!;

  dircopy(
      catdir($sharedir,"statics")
      ,
      catdir($pensource,"statics")
    ) or die $!;

  dircopy(
      catdir($sharedir,"statics")
      ,
      catdir($pensource,"statics")
    ) or die $!;

  say "...done!";
}





1;
