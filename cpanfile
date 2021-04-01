requires 'perl', '5.012';

requires 'File::Spec';
requires 'File::Spec::Functions';
requires 'File::Basename';
requires 'DateTime';
requires 'Carp';
requires 'Encode';
requires 'Encode::Locale';
requires 'YAML';
requires 'POSIX';
requires 'Module::Load';
requires 'Module::Load::Conditional';
requires 'HTTP::Date';
requires 'IO::File';
requires 'URI::Escape';
requires 'LWP::MediaTypes';
requires 'Template';
requires 'YAML';
requires 'Cwd';
requires 'Time::HiRes';
requires 'File::Copy';
requires 'File::Copy::Recursive';
requires 'File::Path';
requires 'File::ShareDir';
requires 'HTTP::Server::Simple::CGI';
requires 'App::Cmd::Setup';
requires 'Markup::Unified';
requires 'Text::Markmoredown';

on test => sub {
    requires 'Test::More', '0.96';
};
requires 'Exporter', '5.59';
