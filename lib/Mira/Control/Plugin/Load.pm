package Mira::Control::Plugin::Load;
$Mira::Control::Plugin::Load::VERSION = '00.07.56';

use strict;
use warnings;
use utf8;
use 5.012;

use Carp;

use Module::Load::Conditional qw(check_install);

use lib 'plugins/lib';


sub check {
    my $class = shift;
    my $source = shift;
    my $config = shift;
    my @check;

    if ($config->{plugins})
    {
        foreach my $plugin (@{$config->{plugins}})
        {
            if (my $chkinst = check_install( module => "Mira::Plugin::$plugin"))
            {
                push @check, "Mira::Plugin::$plugin";
                next;
            }
            if (my $chkinst = check_install( module => $plugin))
            {
                push @check, $plugin;
                next;
            }
        }
    }
    return \@check;
}



1;
