package Mira::CLI::Command::init;
$Mira::CLI::Command::init::VERSION = '0.07';

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
my $user = $ENV{'USER'};
  my $config_file = <<"EOCF";

#general 'mira' config, you can make config files for any floor in /config/FLOOR_NAME.yml

## Site settings
title: Your Site Tilte
description: Description of your site

author: $user
email: your-email\@domain.com

 # the base hostname & protocol for your site
url: http://localhost:80
root: /
static: /static
imageurl: /static/img

## default post permanent link
permalink: :year/:month/:day/:title/

## Your local Time Zone
#TimeZone: +00:00

## Build settings
default_body_format: markdown

## number of posts will be show in main index page
post_num: 3

## number of posts will be show in archives index page
archive_post_num: 10

## if create new entry without --floor switch, mira use this field
default_floor: blog


## template path by root is penurlPATH/template
## if you want use a custom template for examle in penurlPATH/template/CustomThEM
## just type custom template folder name
#> template: Custom_Template_Folde_Name
template: default-theme

## the fields you want use for archive, like category, tag and ...
## by default Mira archive date field dont need type it here
## Mira use this fields by default for the floors which haven't field section
## in FloorName.yaml, or haven't FloorName.yaml file

#this fields are not allowed: archives, static
lists:
  - categories
  - tags
  - author

#url address for long keys or unicode which you want make latin addres for'em
# for example if you have 'longcategoryname' you can make /category/lcn
#namespace:
#  veryverylongarchivename : vlan
#  learnsections: learn
#  mybooksButWithALongname: book
#  aboutThisSite: about
#  myPersonalDailyDiary: personal
#  terminalCommandLearning: terminal

EOCF

  #make_path catdir($cwd,"make_test","conf") unless (-d "$cwd/make_test/conf/config.yml");
  my $file = catfile($pensource, "config.yml");
  open my $fh, '>:encoding(UTF-8)', $file || die;
  print $fh $config_file;
  close $fh;
  }

  make_path catdir($pensource,"content");
  make_path catdir($pensource,"content","blog");

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

}





1;
