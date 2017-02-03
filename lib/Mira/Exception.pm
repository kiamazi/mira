package Mira::Exception;

use strict;
use warnings;
use YAML;
#use Carp;

use 5.012;

sub new {
  my $class = shift;
  my $source = shift;
  my $test_model = shift;
  $test_model = 'config,content' unless ($test_model or $test_model !~ /config|content/);

  #my $self = {};

  #source test
  unless (-e "$source/config.yml" and -d "$source/content" and -d "$source/template")
  {
    return (bless [(
    "lethal",
    "you are not in true path or if use --source, the value is not valid path or one of this directories is deleted
    $source/config.yml
    $source/content
    $source/template
    if you are in true path but folder(s) are not exists you can fix it by run this command line:
       Mira --init --reconf --retmpl
    !!! - this error is not save in your log",
    1
    )], $class)
  }

  #config test
  if ($test_model =~ /config/)
  {
	my $config_test = _config_test($source);
	if (@$config_test)
	{
	bless $config_test, $class;
	return $config_test;
	}
  }


  #content test
  if ($test_model =~ /content/)
  {
	my $content_test = _content_test($source);
	if (@$content_test)
	{
		bless $content_test, $class;
		return $content_test;
	}
  }


  return (bless [], $class)
}




sub _config_test {
  my $source = shift;
  my $test = {};

    unless (-e "$source/config.yml")
    {
      return [(
      "lethal",
      "you are not in true path or --source is invalid path or /config.yml isn't valid",
      2
      )];
    }

    my $yaml;
    {
      open my $fh, '<:encoding(UTF-8)', 'config.yml' or die $!;
      local $/ = undef;
      $yaml = <$fh>;
      close $fh;
    }

    eval
    {
      $test = Load($yaml);
    }; if ($@)
    {
       say foreach $@;
       return [(
       "lethal",
       "the config file ($source/config.yml) have problem",
       3
       )];
    }

    unless (exists $test->{penurl} and $test->{penurl} eq $source)
    {
      return [(
      "lethal",
      "penurl key in ($source/config.yml) is not valid or not equal $source",
      4
      )];
    }

    return [];
}


sub _content_test {
  my $source = shift;

  my @content_directory_list = glob("$source/content/*"); # <"$addr/*">;
  @content_directory_list = grep {-d} @content_directory_list;
  unless (@content_directory_list) {
    return [(
    "notice",
    "content folder($source/content/) is empty",
    1001
    )];
  }

  my $pen_test = 0;
  foreach my $type (@content_directory_list) {
    my @files = glob("$type/*.pen");
    if (@files) {
      $pen_test++;
    }
  }
  unless ($pen_test)
  {
    return [(
    "notice",
    "no .pen file available in your content",
    1002
    )];
  }

  return [];
}



1;
