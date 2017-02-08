package Mira::CLI::Command::new;
$Mira::CLI::Command::new::VERSION = '0.07';

use strict;
use warnings;

use App::Cmd::Setup -command;

use 5.012;

use Cwd;
use File::Spec::Functions;
use File::Path qw(make_path);

use utf8;
binmode STDOUT, ":utf8";


use Mira::Config;

my $cwd = cwd;

sub abstract { 'new entry maker' }

sub description { 'post maker script for Mira static site generator' }

sub opt_spec {
    return (
        [ 'floor|f=s',  'new entry floor'],
        [ 'title|t=s',    'new entry title' ],
        [ 'directory|d=s', 'application path (default: current directory)', { default => $cwd } ],
        [ 'help|h',     'this help' ],

    );
}

sub validate_args {
  my ($self, $opt, $args) = @_;
  my $title = $opt->{title};
  $self->usage_error("your post need a title") unless $title;
  my $path = $opt->{directory};
  -d $path or $self->usage_error("directory '$path' does not exist");
  -f catfile($path, 'config.yml') or _usage_error("directory '$path' does not valid address.\ncant't find config.yml");
  -d catdir($path, 'content') or _usage_error("directory '$path' does not valid address.\ncant't find content folder");
  -d catdir($path, 'template') or _usage_error("directory '$path' does not valid address.\ncant't find template folder");
}

sub execute {
  my ($self, $opt, $args) = @_;
  my $pensource = $cwd;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  $mon += 1;
  my $now_date = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
  my $utid = sprintf "%04d%02d%02d%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec;

  my $config = Mira::Config->new($pensource);

  $opt->{floor} = $config->{_default}->{default_floor} unless $opt->{floor};
  $opt->{floor} = lc($opt->{floor});
  my $floor = $opt->{floor};


  my %segments;
  $segments{utid} = $utid;
  $segments{date} = $now_date;
  $segments{title} = $opt->{title};
  if ($config->{$floor}->{default_body_format} and $config->{$floor}->{default_body_format} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i)
  {
  	$segments{'body-format'} = $config->{$floor}->{default_body_format};
  } elsif ($config->{_default}->{default_body_format} and $config->{_default}->{default_body_format} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i)
  {
  	$segments{'body-format'} = $config->{_default}->{default_body_format};
  } else
  {
  	$segments{'body-format'} = "markdown";
  }
  $segments{author} = $config->{$floor}->{author} ? $config->{$floor}->{author} : ($config->{_default}->{author} ? $config->{_default}->{author} : $ENV{USER});


  my $structure = (-f catfile($pensource, 'structure', 'default')) ? catfile($pensource, 'structure', 'default') : '' ;
  $structure = (-f catfile($pensource, 'structure', $floor)) ? catfile($pensource, 'structure', $floor) : $structure ;

  my $content;
  if ($structure)
  {
  	{
      open my $fh, '<:encoding(UTF-8)', $structure or die $!;
      local $/ = undef;
      $content = <$fh>;
      close $fh;
    }
  } else
  {
  	$content =<<"END_CNTNT";
_index:
_permalink:
title:
author:
categories:
  -
tags:
  -
END_CNTNT
  }
  chomp $content;

my $title = $opt->{title};
$title =~ s/[\W]+$//;
$title =~ s/[\W]+/_/g;

  my $target_post_dir = catdir($pensource, 'content', $floor);
  make_path $target_post_dir unless -d $target_post_dir;

  my $target_post_file;
  if (! -f catfile($target_post_dir, "$year-$mon-$mday-$title.pen")) {
  	$target_post_file = catfile($target_post_dir, "$year-$mon-$mday-$title.pen");
  } else {
  	print "/$opt->{floor}/$year-$mon-$mday-$title.pen already exist\n";
  	while (1) {
  		state $nfid = 2;
  		$nfid = sprintf "%02d", $nfid;
  		$target_post_file = catfile($target_post_dir, "$year-$mon-$mday-$title-$nfid.pen");
  		last unless (-e $target_post_file);
  		$nfid++;
  	}
  }
  open my $fh, '>:encoding(UTF-8)', $target_post_file or die $!;
  print $fh "---\n";
  print $fh "utid: $segments{utid}\n";
  print $fh "date: $segments{date}\n";
  print $fh "title: $segments{title}\n";
  print $fh "_index:\n";
  print $fh $content."\n";
  print $fh "author: $segments{author}\n";
  print $fh "body-format: $segments{'body-format'}\n";
  print $fh "---\n";
  close $fh;
  say "$target_post_file created";

}



sub _usage_error {
  my $message = shift;
  say "ERROR:";
  say $message;
  exit;
}



1;
