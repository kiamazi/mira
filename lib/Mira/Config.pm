package Mira::Config;
$Mira::Config::VERSION = '00.07.56';

use strict;
use warnings;
use utf8;

use YAML;
use File::Spec;
use File::Spec::Functions;
use File::Basename qw/basename/;
use Encode;
use Encode::Locale;

use 5.012;

sub set {
    my $class  = shift;
    my $source = shift;
    my $self = {};
    bless $self, $class;

    $self = $self->_default_config($source);
    $self = $self->_floors_config($source);

    return $self;
}

sub _default_config {
    my ($self, $source) = @_;

    my $config_file = catfile($source, 'config.yml');
    if ( -e $config_file && !-d _ )   # -f $config_file
    {
        $self->{_default} = $self->_doYaml_to_Config($config_file);
    } else
    {
      say " ! - you are not in true path or --source is invalid path or
      /conf/config.yml isn't valid file" and exit;
    }

    $self->{_default}->{root} = "/" unless (exists $self->{_default}->{root} and $self->{_default}->{root});
    $self->{_default}->{root} =~ s{^(.*)?:/+}{/}g;
    $self->{_default}->{root} =~ s{/+}{/}g;
    $self->{_default}->{url} = "/" unless (exists $self->{_default}->{url} and $self->{_default}->{url});
    $self->{_default}->{url} =~ s{(?<!:)/+}{/}g;
    $self->{_default}->{publishDIR} = 'public' unless (exists $self->{_default}->{publishDIR} and $self->{_default}->{publishDIR});

    $self->{_default}->{post_num} = "5" unless (exists $self->{_default}->{post_num} and $self->{_default}->{post_num});
    $self->{_default}->{archive_post_num} = "20" unless (exists $self->{_default}->{archive_post_num} and $self->{_default}->{archive_post_num});
    $self->{_default}->{feed_post_num} = "20" unless (exists $self->{_default}->{feed_post_num} and $self->{_default}->{feed_post_num});
    $self->{_default}->{default_floor} = "blog" unless (exists $self->{_default}->{default_floor} and $self->{_default}->{default_floor});
    $self->{_default}->{permalink} = ":year/:month/:day/:title/" unless (exists $self->{_default}->{permalink} and $self->{_default}->{permalink});
    $self->{_default}->{default_markup} = "markmod" unless (exists $self->{_default}->{default_markup} and $self->{_default}->{default_markup});
    $self->{_default}->{default_extension} = "md" unless (exists $self->{_default}->{default_extension} and $self->{_default}->{default_extension});
#    $self->{_default}->{static} = "/static" unless (exists $self->{_default}->{static} and $self->{_default}->{static});
#    $self->{_default}->{imageurl} = "/static/images" unless (exists $self->{_default}->{imageurl} and $self->{_default}->{imageurl});
    $self->{_default}->{timezone} = "+00:00" unless (exists $self->{_default}->{timezone} and $self->{_default}->{timezone});
    $self->{_default}->{t_start_tag} = "{{" unless (exists $self->{_default}->{t_start_tag} and $self->{_default}->{t_start_tag});
    $self->{_default}->{t_end_tag} = "}}" unless (exists $self->{_default}->{t_end_tag} and $self->{_default}->{t_end_tag});
    $self->{_default}->{t_outline_tag} = "%%" unless (exists $self->{_default}->{t_outline_tag} and $self->{_default}->{t_outline_tag});
    $self->{_default}->{feed_output} = 'feed.xml' unless (exists $self->{_default}->{feed_output} and $self->{_default}->{feed_output});
    $self->{_default}->{feed_template} = 'atom.tt2' unless (exists $self->{_default}->{feed_template} and $self->{_default}->{feed_template});

    return $self;
}

sub _floors_config {
    my ($self, $source) = @_;
    my $yaml;

    my $glob = catfile($source, 'content', '*');

    my @floors = glob encode(locale_fs => $glob);
    @floors = grep {-d} @floors;
    @floors = map {decode(locale_fs => basename($_))} @floors;

    foreach my $floor (@floors)
    {
        my $config_file = catfile($source, 'config', "$floor.yml");
        if ( -e $config_file && !-d _ )
        {
            $self->{$floor} = $self->_doYaml_to_Config($config_file, $floor);
            $self->{$floor}->{title} = $floor unless ($self->{$floor}->{title});
            $self->{$floor}->{root} = "$self->{_default}->{root}/$floor/" unless ($self->{$floor}->{root});
            $self->{$floor}->{url} = "$self->{_default}->{url}/$floor/" unless ($self->{$floor}->{url});
#            $self->{$floor}->{static} = "$self->{$floor}->{root}/static/" unless ($self->{$floor}->{static});
#            $self->{$floor}->{imageurl} = "$self->{$floor}->{root}/static/images/" unless ($self->{$floor}->{imageurl});
        } else
        {
            $self->{$floor} = $self->_not_valids($floor);
        }

        $self->{$floor}->{url} =~ s{(?<!:)/+}{/}g;
        #$self->{$floor}->{url} =~ s{((?:(?!.*?:)/+))}{/}g;
        $self->{$floor}->{root} =~ s{^(.*?):/+}{/}g;
        $self->{$floor}->{root} =~ s{/+}{/}g;
#        $self->{$floor}->{static} =~ s{/+}{/}g;

        foreach my $key (keys %{ $self->{_default} })
        {
            $self->{$floor}->{$key} = $self->{_default}->{$key}
            if (not exists $self->{$floor}->{$key});
        }
    }
    return $self;
}

sub _doYaml_to_Config {
    my $self         = shift;
    my $config_file  = shift;
    my $is_floor     = shift;
    my $file_content;
    my $yaml;

    {
        open my $fh, '<:encoding(UTF-8)', $config_file or die $!;
        local $/ = undef;
        $file_content = <$fh>;
        close $fh;
    }
    eval { #must read yaml message and print it in error output
        $yaml = Load( $file_content );
    }; if ($@ and not $is_floor)
    {
        say "$config_file have problem" and exit;
    } elsif ($@ and $is_floor)
    {
        say " # - $is_floor\.yml have problem, use default configs for floor: $is_floor";
        $yaml = $self->_not_valids($is_floor);
    }
    return $yaml;
}

sub _not_valids {
    my $self    = shift;
    my $floor   = shift;
    my $configs = {
        title    => $floor,
        root     => $self->{_default}->{root} . "/" . $floor . "/",
        url      => $self->{_default}->{url}  . "/" . $floor . "/",
#        static   => $self->{_default}->{root} . "/" . $floor . "/static",
#        imageurl => $self->{_default}->{root} . "/" . $floor . "/static/images/",
    };

    return $configs;
}

1;
