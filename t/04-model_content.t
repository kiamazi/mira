use strict;
use warnings;
use 5.012;

use utf8;
binmode STDOUT, ":utf8";

use Mira::Control::Content::Load;

use File::Temp;
use File::Spec;
use File::Spec::Functions;
use File::Path qw(make_path);
use FindBin;

use Test::More tests => 11;


my $dir = File::Temp->newdir();
chdir $dir;

make_path catdir($dir,'content','blog') unless (-d catdir($dir,'content','blog'));
make_path catdir($dir,'content','pages') unless (-d catdir($dir,'content','pages'));
make_path catdir($dir,'content','books') unless (-d catdir($dir,'content','books'));
make_path catdir($dir,'content','یونیکد') unless (-d catdir($dir,'content','یونیکد'));


my $content = Mira::Control::Content::Load->new(source => $dir, ext => '.draft');
ok ($content);

my $floors = $content->floors;
ok ($#$floors == 3);

my %floor_test;
foreach my $floor (@$floors) {
  $floor_test{$floor} = $floor;
}

ok ($floor_test{blog} eq 'blog');
ok ($floor_test{pages} eq 'pages');
ok ($floor_test{books} eq 'books');
ok ($floor_test{یونیکد} eq 'یونیکد');


my $post =<<"END_CNTNT";
utid: 12341212121212
_index: tset
_permalink: /test/
title: test post
author: tester
categories:
 - cat1
 - cat2
tags:
 - tag1
 - tag2
 - tag3
---
hello world

this is a test
END_CNTNT

chomp $post;

my $target_post_file = catfile($dir, 'content', 'یونیکد', 'testpost.pen');
open my $fh1, '>:encoding(UTF-8)', $target_post_file or die $!;
print $fh1 $post."\n";
close $fh1;

$target_post_file = catfile($dir, 'content', 'blog', 'testpost.pen');
open my $fh2, '>:encoding(UTF-8)', $target_post_file or die $!;
print $fh2 $post."\n";
close $fh2;

my $files = $content->files($floors);
ok ($files);

ok (@{ $files->{یونیکد} });
ok ($files->{یونیکد}[0] = catfile($dir, 'content', 'یونیکد', 'testpost.pen'));
ok (@{ $files->{blog} });
ok ($files->{blog}[0] = catfile($dir, 'content', 'blog', 'testpost.pen'));

chdir $FindBin::Bin;
