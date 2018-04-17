package Mira::Control::Plugin::Plug;
$Mira::Control::Plugin::Plug::VERSION = '00.07.56';

use strict;
use warnings;
use utf8;
use 5.012;

use Carp;

use Module::Load;

use lib 'plugins/lib';


sub plug {
    my $class = shift;
    my $source = shift;
    my $plugins = shift;
    my $apis = shift;

    foreach my $plugin (@$plugins)
    {
        #eval "require $plug->{lib}";
        #$plugin->{lib} .= '.pm' if $plugin->{lib} !~ /\.pm$/;
        load $plugin;
        eval {$plugin->plug($apis)};

        ###### TODO need better checks and error messages ######
        #say "! plugin error: " . $plug_yaml . " > " . $plug->{name} . " need plug method" if $@;
    }



}

1;
