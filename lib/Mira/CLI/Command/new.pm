package Mira::CLI::Command::new;
$Mira::CLI::Command::new::VERSION = '00.07.34';

use strict;
use warnings;

use App::Cmd::Setup -command;

use 5.012;

use Cwd;
use File::Spec;
use File::Spec::Functions;
use File::Path qw(make_path);
use Encode;
use Encode::Locale;

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
    my $source = $opt->{directory};

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;
    my $now_date = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
    my $utid = sprintf "%04d%02d%02d%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec;

    my $config = Mira::Config->new($source);

    $opt->{floor} = $config->{_default}->{default_floor} unless $opt->{floor};
    $opt->{floor} = lc($opt->{floor});
    my $floor = $opt->{floor};

    my $ext = $config->{$floor}->{default_extension} ? $config->{$floor}->{default_extension} : 'md';
    $ext =~ s/\.+//;

    my %segments;
    $segments{utid} = $utid;
    $segments{date} = $now_date;
    $segments{title} = decode(locale_fs => $opt->{title});
#    if ($config->{$floor}->{default_markup} and $config->{$floor}->{default_markup} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i)
#    {
#  	    $segments{markup} = $config->{$floor}->{default_markup};
#    } elsif ($config->{_default}->{default_markup} and $config->{_default}->{default_markup} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i)
#    {
#  	    $segments{markup} = $config->{_default}->{default_markup};
#    } else
#    {
#  	    $segments{markup} = "markdown";
#    }
#    $segments{author} = $config->{$floor}->{author} ? $config->{$floor}->{author} : ($config->{_default}->{author} ? $config->{_default}->{author} : $ENV{USER});


    my $structure = (-f catfile($source, 'structure', 'default')) ? catfile($source, 'structure', 'default') : '' ;
    $structure = (-f catfile($source, 'structure', $floor)) ? catfile($source, 'structure', $floor) : $structure ;

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
        #$content =<<"END_CNTNT";
        #categories:
        # -
        #tags:
        # -
        #END_CNTNT
        $content = "_index: ";
    }
    chomp $content;

    my $title = decode(locale_fs => $opt->{title});
    $title =~ s/[\W]+$//;
    $title =~ s/[\W]+/-/g;

    my $target_post_dir = catdir($source, 'content', $floor);
    make_path $target_post_dir unless -d $target_post_dir;

    my $target_post_file;
    if (! -f catfile($target_post_dir, "$year-$mon-$mday-$title.$ext")) {
  	    $target_post_file = catfile($target_post_dir, "$year-$mon-$mday-$title.$ext");
    } else {
  	    print "/$opt->{floor}/$year-$mon-$mday-$title.$ext already exist\n";
  	    while (1) {
            state $nfid = 2;
            $nfid = sprintf "%02d", $nfid;
            $target_post_file = catfile($target_post_dir, "$year-$mon-$mday-$title-$nfid.$ext");
            last unless (-e $target_post_file);
            $nfid++;
  	    }
    }
    open my $fh, '>:encoding(UTF-8)', $target_post_file or die $!;
    print $fh "---\n";
    print $fh "utid: $segments{utid}\n";
    print $fh "date: $segments{date}\n";
    print $fh "title: $segments{title}\n";
#   print $fh "_index:\n";
    print $fh $content."\n";
#   print $fh "author: $segments{author}\n";
#   print $fh "_markup: $segments{markup}\n";
    print $fh "---\n";
    close $fh;
    say "$target_post_file created";
    #system ("gedit $target_post_file&");

}



sub _usage_error {
  my $message = shift;
  say "ERROR:";
  say $message;
  exit;
}



1;
