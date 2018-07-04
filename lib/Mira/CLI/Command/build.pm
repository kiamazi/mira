package Mira::CLI::Command::build;
$Mira::CLI::Command::build::VERSION = '00.07.56';

use strict;
use warnings;

use App::Cmd::Setup -command;

use 5.012;

use Cwd;
use File::Spec;
use File::Spec::Functions;
use Time::HiRes;

use utf8;
binmode STDOUT, ":encoding(UTF-8)";

my $cwd = cwd;

sub abstract { 'site builder' }

sub description { 'builder script for Mira static site generator' }

sub opt_spec {
    return (
        ['directory|d=s','application path (default: current directory)',{ default => $cwd }],
        ['floor|f=s',    'floor you want build'],
        ['draft|d',      'build with draft files'],
        [ 'help|h',      'this help' ],
    );
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    my $path = $opt->{directory};
    -d $path or $self->usage_error("directory '$path' does not exist");
    -f catfile( $path, 'config.yml' ) or _usage_error
        (
            "directory '$path' does not valid address.\ncant't find config.yml"
        );
    -d catdir( $path, 'content' ) or _usage_error
        (
            "directory '$path' does not valid address.\ncant't find content folder"
        );
    -d catdir( $path, 'template' ) or _usage_error
        (
            "directory '$path' does not valid address.\ncant't find template folder"
        );
    if ($opt->{floor})
    {
        -d catdir( $path, 'content', $opt->{floor} ) or _usage_error
        (
            "floor: '$opt->{floor}' does not exists"
        );
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;
    my $start_time = [ Time::HiRes::gettimeofday() ];

    my $source      = $opt->{directory};
    my $floorsource = $opt->{floor} ? catdir('content', $opt->{floor}) : '';
    my $draft_ext       = $opt->{draft} ? '' : '.draft';

    my $config      = Mira::Config->set($source);

    ######################
    use Mira::Control::Content;

    my $bases = Mira::Control::Content->preparator(
        source       => $source     ,
        draft_ext    => $draft_ext  ,
        config       => $config     ,
        floorsource  => $floorsource,
    );

    my $statics      = $bases->{statics};
    my $data_base    = $bases->{data};
    my $floors_base  = $bases->{floor};
    my $archive_base = $bases->{archive};

    ######################
    ######################
    my $diff = Time::HiRes::tv_interval($start_time);
    print "make database time: $diff\n";

    ######################
    use Mira::Plugin;
    use Mira::Control::Plugin::Load;
    use Mira::Control::Plugin::Plug;

    foreach my $floor ( keys %$floors_base ) {
        my $plugins =
          Mira::Control::Plugin::Load->check( $source, $config->{$floor} );
        my $apis =
          Mira::Plugin->new( $floor, $data_base, $archive_base, $config );

        Mira::Control::Plugin::Plug->plug( $source, $plugins, $apis );
    }

    ######################
    ######################
    $diff = Time::HiRes::tv_interval($start_time);
    print "pluging: $diff\n";

    ######################
    my $publishdir = $config->{_default}->{publishDIR};
    use Mira::Control::Static;
    my $static_path =
      Mira::Control::Static->address( $statics, $config, $source, $publishdir );
    my $total_statics = Mira::Control::Static->copy($static_path);

    say $total_statics . " files and directories copied to static folders";
    ######################
    ######################
    $diff = Time::HiRes::tv_interval($start_time);
    print "statics copied: $diff\n";



    ######################
    use Mira::Model::Address;
    my $address_base = Mira::Model::Address->new;


    ######################
    my @utids = keys %$data_base;
    @utids = reverse sort { $a <=> $b } @utids;
    my $posts = \@utids;

    my $floor_data = {};
    foreach my $floor ( keys %$floors_base ) {
        my @entries = reverse sort @{ $floors_base->{$floor} };
        @entries = grep {
            not $data_base->{$_}->{_type}
             or $data_base->{$_}->{_type} !~ m/^page$/i
        } @entries;
        splice @entries, $config->{_default}->{post_num}
          if ( $config->{_default}->{post_num} ne 'all' );
        $floor_data->{$floor}->{name}        = $config->{$floor}->{title};
        $floor_data->{$floor}->{description} = $config->{$floor}->{description};
        $floor_data->{$floor}->{url}         = $config->{$floor}->{url};
        $floor_data->{$floor}->{root}        = $config->{$floor}->{root};
        $floor_data->{$floor}->{SITE}        = $config->{$floor};
        foreach my $utid (@entries) {
            push @{ $floor_data->{$floor}->{posts} }, $data_base->{$utid};
        }
    }

    ######################
    use DateTime;
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    $year += 1900;
    $mon  += 1;
    my $now_date = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday,
      $hour, $min, $sec;
    my $date_time = DateTime->new(
        year  => $year,
        month => $mon,
        day   => $mday,
    );
    my $month_name = $date_time->month_name;
    my $month_abbr = $date_time->month_abbr;
    my $day_name   = $date_time->day_name;
    my $day_abbr   = $date_time->day_abbr;

    my $build = {};
    $build->{date}       = $now_date;
    $build->{year}       = sprintf "%04d", $year;
    $build->{month}      = sprintf "%02d", $mon;
    $build->{month_name} = $month_name;
    $build->{month_abbr} = $month_abbr;
    $build->{day}        = sprintf "%02d", $mday;
    $build->{day_name}   = $day_name;
    $build->{day_abbr}   = $day_abbr;
    $build->{hour}       = sprintf "%02d", $hour;
    $build->{minute}     = sprintf "%02d", $min;
    $build->{second}     = sprintf "%02d", $sec;

    ######################
    use Mira::View;

    $diff = Time::HiRes::tv_interval($start_time);
    print "start main: $diff\n";

    Mira::View::Main->template(
        config       => $config,
        posts        => $posts,         #utids
        allentries   => $data_base,     #all entries hash
        floors       => $floors_base,
        pensource    => $source,
        floor_data   => $floor_data,
        build        => $build,
        address_base => $address_base,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start floor indexes: $diff\n";

    Mira::View::Floor->template(
        config       => $config,
        posts        => $posts,          #utids
        allentries   => $data_base,      #all entries hash
        floors       => $floors_base,
        pensource    => $source,
        archives     => $archive_base,
        floor_data   => $floor_data,
        build        => $build,
        address_base => $address_base,
    );

    Mira::View::Feed->template(
        config       => $config,
        posts        => $posts,          #utids
        allentries   => $data_base,      #all entries hash
        floors       => $floors_base,
        pensource    => $source,
        archives     => $archive_base,
        floor_data   => $floor_data,
        build        => $build,
        address_base => $address_base,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start archives indexes: $diff\n";

    Mira::View::Archive->template(
        config       => $config,
        posts        => $posts,          #utids
        allentries   => $data_base,      #all entries hash
        floors       => $floors_base,
        pensource    => $source,
        archives     => $archive_base,
        floor_data   => $floor_data,
        build        => $build,
        address_base => $address_base,
    );

    $diff = Time::HiRes::tv_interval($start_time);
    print "start post indexes: $diff\n";

    Mira::View::Post->template(
        config       => $config,
        posts        => $posts,          #utids
        allentries   => $data_base,      #all entries hash
        floors       => $floors_base,
        pensource    => $source,
        archives     => $archive_base,
        floor_data   => $floor_data,
        build        => $build,
        address_base => $address_base,
    );

    $diff = Time::HiRes::tv_interval($start_time);

    #print "The program ran for ", time() - $^T, " seconds\n";





    use File::Spec;
    use File::Spec::Functions;
    use Template;

    foreach my $of (keys %$address_base)
    {
        my $output_root = $address_base->{$of}->{template_root};

        my $output_index = Template->new({
            INCLUDE_PATH => [$output_root , catdir($output_root, 'include') ],
            INTERPOLATE  => 1,
            TRIM      => 1,
            EVAL_PERL => 1,
            ENCODING => 'utf8',
            START_TAG => $address_base->{$of}->{START_TAG},
            END_TAG   => $address_base->{$of}->{END_TAG},
            OUTLINE_TAG => $address_base->{$of}->{OUTLINE_TAG},
        }) || die "$Template::ERROR\n";

        my $vars = $address_base->{$of}->{vars};

        $output_index->process(
            $address_base->{$of}->{template_file},
            $vars,
            $address_base->{$of}->{output},
            { binmode => ':utf8' }
        ) || die $output_index->error(), "\n";
    }



$diff = Time::HiRes::tv_interval($start_time);
print "\nThe program ran for ", $diff, " seconds\n";

}

sub _usage_error {
    my $message = shift;
    say "ERROR:";
    say $message;
    exit;
}

1;
