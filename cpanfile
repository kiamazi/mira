requires 'perl', '5.012';

require File::Spec;
require File::Spec::Functions;
require File::Basename;
require DateTime;
require Carp;
require Encode;
require Encode::Locale;
require YAML;
require POSIX;
require Module::Load;
require Module::Load::Conditional;
require HTTP::Date;
require IO::File;
require URI::Escape;
require LWP::MediaTypes;
require Template;
require YAML;
require Cwd;
require Time::HiRes;
require File::Copy;
require File::Copy::Recursive;
require File::Path;
require File::ShareDir;
require HTTP::Server::Simple::CGI;
require App::Cmd::Setup;

on test => sub {
    requires 'Test::More', '0.96';
};
requires 'Exporter', '5.59';
