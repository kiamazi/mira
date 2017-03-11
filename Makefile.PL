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
  EXE_FILES        => [
      "bin/mira"
  ],
  MIN_PERL_VERSION => 5.012,
  CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker'       => 0,
        'File::ShareDir::Install'   => 0,
  },
  PREREQ_PM => {
        'App::Cmd'              => 0,
        'YAML'                  => 0,
        'Template'              => 0,
        'Markup::Unified'       => 0,
        'Encode::Locale'        => 0,
        'File::Copy::Recursive' => 0,
        'File::ShareDir'        => 0,
        'DateTime'              => 0,
        'Plack'                 => 0,
        'Text::Textile'         => "2.12",
        'Text::Markdown'        => "1.0.25",
        'HTML::BBCode'          => "2.06",
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
