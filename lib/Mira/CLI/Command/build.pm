package Mira::CLI::Command::build;

use strict;
use warnings;

use App::Cmd::Setup -command;

use 5.012;

use Cwd;
use File::Spec::Functions;
use File::Path qw(make_path);
use File::Copy::Recursive qw(dircopy);
use File::Basename qw/basename/;
use Time::HiRes;

use utf8;
binmode STDOUT, ":utf8";

use FindBin; #qw($bin)
use lib "$FindBin::Bin/lib";
use Mira;

my $cwd = cwd;

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
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $start_time = [Time::HiRes::gettimeofday()];

    my $pensource = $opt->{directory};

    my $except = Mira::Exception->new($pensource,'config,content');
    @$except ? err_chk(@$except) : log_save("exception test: ok", 0, "ok", $pensource);

    my $config = Mira::Config->new($pensource);

    my $fields = Mira::Field->new($pensource,$config);
    $config->{_default}->{permalink} = ":year/:month/:title" if ($config->{_default}->{permalink} !~ m/:(year|month|day|title)/i);
    $config->{_default}->{permalink} .= "/:title" if ($config->{_default}->{permalink} !~ m/:title/i);
    my $data = Mira::Data->new(
    		source => $pensource,
    		config => $config,
    		markup => $config->{_default}->{default_body_format},
    		baseurl => $config->{_default}->{root},
    		permalink => $config->{_default}->{permalink},
    		imgurl => $config->{_default}->{imgurl},
    );


    my $lists = $data->lists($fields, $config);
    $lists = { %{$lists} };

    my $floors = $data->floors;

    my $diff = Time::HiRes::tv_interval($start_time);
    print "make database time: $diff\n";

    dircopy(
    catdir($pensource, 'statics')
    ,
    catdir($pensource, 'public', $config->{_default}->{static})
    );


    my @utids = keys %$data;
    @utids = reverse sort @utids;
    my $posts = \@utids;

    my $data_base = { %$data };
    my $floors_base = { %$floors };

    my $floor_data = {};
    foreach my $floor (keys %$floors)
    {
      my @entries = reverse sort @{$floors->{$floor}};
      splice @entries, $config->{_default}->{post_num} if ($config->{_default}->{post_num} ne 'all');
      $floor_data->{$floor}->{name} = $config->{$floor}->{title};
      $floor_data->{$floor}->{description} = $config->{$floor}->{description};
      $floor_data->{$floor}->{url} = $config->{$floor}->{root};
      foreach my $utid (@entries)
      {
        push @{ $floor_data->{$floor}->{posts} }, $data->{$utid};
      }
    }


    $diff = Time::HiRes::tv_interval($start_time);
    print "start main: $diff\n";

    Mira::View::Main->template(
    	config => $config,
    	posts => $posts, #utids
    	allentries => $data_base, #all entries hash
    	floors => $floors_base,
    	pensource => $pensource,
    	floor_data => $floor_data,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start floor indexes: $diff\n";

    Mira::View::Floor->template(
    	config => $config,
    	posts => $posts, #utids
    	allentries => $data_base, #all entries hash
    	floors => $floors_base,
    	pensource => $pensource,
    	lists => $lists,
    	floor_data => $floor_data,
    );

    Mira::View::Feed->template(
    	config => $config,
    	posts => $posts, #utids
    	allentries => $data_base, #all entries hash
    	floors => $floors_base,
    	pensource => $pensource,
    	lists => $lists,
    	floor_data => $floor_data,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start archives indexes: $diff\n";

    Mira::View::Archive->template(
    	config => $config,
    	posts => $posts, #utids
    	allentries => $data_base, #all entries hash
    	floors => $floors_base,
    	pensource => $pensource,
    	lists => $lists,
    	floor_data => $floor_data,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start post indexes: $diff\n";

    Mira::View::Post->template(
    	config => $config,
    	posts => $posts, #utids
    	allentries => $data_base, #all entries hash
    	floors => $floors_base,
    	pensource => $pensource,
    	lists => $lists,
    	floor_data => $floor_data,
    );

    print "The program ran for ", time() - $^T, " seconds\n";


}

sub err_chk {
  my $level = shift;
  my $message = shift;
  my $err_num = shift;
  say $message;
  log_save($message, $err_num, $level);
  say "lethal problem" and exit if ($level eq "lethal" or $err_num == 1001 or 1002);
}

sub log_save {
  my $message = shift;
  my $err_num = shift;
  my $level = shift;
  my $pensource = shift;
  return if ($err_num == 1);
  make_path catdir($pensource, 'log') unless (-d catdir($pensource, 'log'));
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $mon = sprintf "%02d", $mon+1;
  $year += 1900;
  my $symb = $level eq "ok" ? "+" : $level eq "lethal" ? "!" : "#";
  if (open my $logfile, '>>:encoding(UTF-8)', "$pensource/log/log.txt") {
    print $logfile " $symb - $year/$mon/$mday|$hour:$min:$sec - $err_num - $message\n";
    close $logfile;
  }
}





1;
