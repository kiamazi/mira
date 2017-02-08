package Mira::CLI::Command::build;
$Mira::CLI::Command::build::VERSION = '0.07';

use strict;
use warnings;

use App::Cmd::Setup -command;

use 5.012;

use Cwd;
use File::Spec;
use File::Spec::Functions;
use File::Copy::Recursive qw(dircopy);
use Time::HiRes;

use utf8;
binmode STDOUT, ":utf8";


my $cwd = cwd;
my $source;
my $config;

sub abstract { 'site builder' }

sub description { 'builder script for Mira static site generator' }

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
  -f catfile($path, 'config.yml') or _usage_error("directory '$path' does not valid address.\ncant't find config.yml");
  -d catdir($path, 'content') or _usage_error("directory '$path' does not valid address.\ncant't find content folder");
  -d catdir($path, 'template') or _usage_error("directory '$path' does not valid address.\ncant't find template folder");
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $start_time = [Time::HiRes::gettimeofday()];

    $source = $opt->{directory};
    $config = Mira::Config->new($source);


    ######################
    use Mira::Model::Base;
    my $data = Mira::Model::Base->new;
    ######################
    use Mira::Model::Floor;
    my $floors_data = Mira::Model::Floor->new;

    ######################
    use Mira::Model::Content;
    my $content = Mira::Model::Content->new(source => $source, ext => 'pen');
    my $floors = $content->floors;
    my $files = $content->files($floors);


    ######################
    use Mira::Parser::Entry;
    use Mira::Control::Date;
    use Mira::Control::Jdate;
    use Mira::Parser::Markup;
    use Mira::Parser::img;

    foreach my $floor (@$floors)
    {
      foreach my $file (@{$files->{$floor}})
      {
        my $parser = Mira::Parser::Entry->parse(entry => $file, floor => $floor);
        next unless $parser;

        my $utid = $parser->{utid};
        my $values = $parser->{values};
        if (not exists $data->{$utid})
        {
          Mira::Control::Date->date($values);
          Mira::Control::Jdate->jdate($values) if ($config->{$floor}->{date_format} and $config->{$floor}->{date_format} eq 'jalali');
          $values->{body} = Mira::Parser::Markup->markup(
                                    $values->{body},
                                    _markup_lang($values),
                                    );
          $values->{body} = Mira::Parser::img->replace(
                                    $values->{body},
                                    _img_url($floor),
                                    );
          $data->add($parser->{utid}, $values);
          $floors_data->add($floor, $utid);
        } else
        {
          say "this files have same utid, plz fix it\n"
          .">". $file
          .">". $data->{$utid}->{_spec}->{file_address} ."\n";
        }

      }
    }

    ######################
    use Mira::Control::Address;
    Mira::Control::Address->address($data, $config);

    ######################
    use Mira::Model::Lists;
    my $lists_data = Mira::Model::Lists->lists($data, $config);

    ######################
    ######################
    ######################
    ######################
    ######################
    my $diff = Time::HiRes::tv_interval($start_time);
    print "make database time: $diff\n";
    dircopy(
    catdir($source, 'statics')
    ,
    catdir($source, 'public', $config->{_default}->{static})
    );


    my @utids = keys %$data;
    @utids = reverse sort @utids;
    my $posts = \@utids;

    my $data_base = { %$data };
    my $floors_base = { %$floors_data };

    my $floor_data = {};
    foreach my $floor (keys %$floors_data)
    {
      my @entries = reverse sort @{$floors_data->{$floor}};
      splice @entries, $config->{_default}->{post_num} if ($config->{_default}->{post_num} ne 'all');
      $floor_data->{$floor}->{name} = $config->{$floor}->{title};
      $floor_data->{$floor}->{description} = $config->{$floor}->{description};
      $floor_data->{$floor}->{url} = $config->{$floor}->{root};
      foreach my $utid (@entries)
      {
        push @{ $floor_data->{$floor}->{posts} }, $data->{$utid};
      }
    }


    ######################
    use Mira::View;


    $diff = Time::HiRes::tv_interval($start_time);
    print "start main: $diff\n";

    Mira::View::Main->template(
      config => $config,
      posts => $posts, #utids
      allentries => $data_base, #all entries hash
      floors => $floors_base,
      pensource => $source,
      floor_data => $floor_data,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start floor indexes: $diff\n";

    Mira::View::Floor->template(
      config => $config,
      posts => $posts, #utids
      allentries => $data_base, #all entries hash
      floors => $floors_base,
      pensource => $source,
      lists => $lists_data,
      floor_data => $floor_data,
    );

    Mira::View::Feed->template(
      config => $config,
      posts => $posts, #utids
      allentries => $data_base, #all entries hash
      floors => $floors_base,
      pensource => $source,
      lists => $lists_data,
      floor_data => $floor_data,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start archives indexes: $diff\n";

    Mira::View::Archive->template(
      config => $config,
      posts => $posts, #utids
      allentries => $data_base, #all entries hash
      floors => $floors_base,
      pensource => $source,
      lists => $lists_data,
      floor_data => $floor_data,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start post indexes: $diff\n";

    Mira::View::Post->template(
      config => $config,
      posts => $posts, #utids
      allentries => $data_base, #all entries hash
      floors => $floors_base,
      pensource => $source,
      lists => $lists_data,
      floor_data => $floor_data,
    );

    print "The program ran for ", time() - $^T, " seconds\n";


}

sub _markup_lang {
  my $post = shift;
  my $floor = $post->{floor};
  my $markup_lang;
  if ($post->{'body-format'} and $post->{'body-format'} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i)
  {
    $markup_lang = $post->{'body-format'};
  } elsif (
    $config->{$floor} and
    $config->{$floor}->{default_body_format} and
    $config->{$floor}->{default_body_format} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i
    )
  {
    $markup_lang = $config->{$floor}->{default_body_format};
  } elsif (
    $config->{_default}->{default_body_format} and
    $config->{_default}->{default_body_format} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i
    )
  {
    $markup_lang = $config->{_default}->{default_body_format};
  } else
  {
    $markup_lang = 'markdown';
  }
  $markup_lang = 'markdown' if $markup_lang eq 'md';
  return $markup_lang;
}

sub _img_url {
  my $floor = shift;
  my $imgurl;
  if ($config->{$floor} and $config->{$floor}->{imageurl})
  {
    $imgurl = $config->{$floor}->{imageurl};
  } elsif ($config->{_default}->{imageurl})
  {
    $imgurl = $config->{_default}->{imageurl};
  } elsif ($config->{$floor} and $config->{$floor}->{root})
  {
    $imgurl = "/$config->{$floor}->{root}/static/img/";
  } else
  {
    $imgurl = "/$floor/static/img/";
  }
  $imgurl =~ s:/+:/:g;
  return $imgurl;
}

sub _usage_error {
  my $message = shift;
  say "ERROR:";
  say $message;
  exit;
}



1;
