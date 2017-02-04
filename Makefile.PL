use strict;
use warnings;
use utf8;

use 5.012;

use ExtUtils::MakeMaker;
use File::ShareDir::Install;

install_share dist => 'share';


WriteMakefile
(
  NAME             => 'Mira',
  AUTHOR           => 'Kiavash',
  VERSION_FROM     => 'lib/Mira.pm',
  ABSTRACT         => 'multiple website content management framework',
  LICENSE          => 'gpl_3',
  EXE_FILES        => [grep { -x } glob 'bin/*'],
  MIN_PERL_VERSION => 5.012,
  CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker'       => 0,
        'File::ShareDir::Install'   => 0,
  },
  PREREQ_PM => {
        'Carp'                  => 0,
        'Cwd'                   => 0,
        'App::Cmd'              => 0,
        'Encode'                => 0,
        'YAML'                  => 0,
        'Template'              => 0,
        'Markup::Unified'       => 0,
        'Encode::Locale'        => 0,
        'Exporter'              => 0,
        'File::Basename'        => 0,
        'File::Copy'            => 0,
        'File::Copy::Recursive' => 0,
        'File::Path'            => 0,
        'File::ShareDir'        => 0,
        'File::Spec'            => 0,
        'File::Spec::Functions' => 0,
        'FindBin'               => 0,
        'Getopt::Long'          => 0,
        'Plack'                 => 0,
},
  TEST_REQUIRES => {
        'Test::More'            => 0,
  },
  dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
  META_MERGE => {
    'meta-spec' => { version => 2 },
    resources => {
      repository => {
          type => 'git',
          url  => 'https://github.com/kiamazi/mira.git',
          web  => 'https://github.com/kiamazi/mira',
      },
    },
  },
);



package MY;
use File::ShareDir::Install qw(postamble);

1;
