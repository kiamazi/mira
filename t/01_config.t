use strict;
use warnings;
use utf8;
use 5.012;


use Mira::Config;

use File::Temp;
use File::Spec::Functions;
use File::Path qw(make_path);
use FindBin;

use Test::More tests => 3;

my $dir = File::Temp->newdir();
chdir $dir;



my $config_file = <<"EOCF";

#general 'mira' config, you can make config files for any floor in /config/FLOOR_NAME.yml

## Site settings
title: Your Site Tilte
description: Description of your site

author: TEST_USER
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

## Mira's main directory in your pc
penurl: $dir


## template path by root is penurlPATH/template
## if you want use a custom template for examle in penurlPATH/template/CustomThEM
## just type custom template folder name
#> template: Custom_Template_Folde_Name
template: mira-theme-rtl

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
namespace:
  veryverylongarchivename : vlan
  آموزش: learn
  کتاب: book
  درباره: about
  شخصی: personal
  ترمینال: terminal

EOCF

  #make_path catdir($cwd,"make_test","conf") unless (-d "$cwd/make_test/conf/config.yml");
  my $file = catfile($dir, "config.yml");
  open my $fh, '>:encoding(UTF-8)', $file || die;
  print $fh $config_file;
  close $fh;


my $config = Mira::Config->new($dir);

chdir $FindBin::Bin;


ok ($config->{_default}->{penurl} eq $dir);
ok ($config->{_default}->{author} eq 'TEST_USER');
ok (ref($config->{_default}->{lists}) eq 'ARRAY');
