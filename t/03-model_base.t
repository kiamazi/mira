use strict;
use warnings;
use utf8;
use 5.012;


use Mira::Model::Base;


use Test::More tests => 4;


my $data = Mira::Model::Base->new;

my $string1 = '12345678901234';
my $hashref1 = {
  date => '2020-02-20 20:02:02',
  title => 'test',
  author => 'tester',
  body => {
    less => 'less body',
    more => "more more more more
    more more more more more
    more body",
  },
};

my $string2 = '12345678901235';
my $hashref2 = {
  date => '2020-02-20 20:02:20',
  title => 'test2',
  author => 'tester',
  body => {
    less => 'less body2',
    more => "more more more more
    more more more more more
    more body2",
  },
};


ok ($data->add($string1, $hashref1));
ok ($data->add($string2, $hashref2));
ok ($data->{12345678901234}->{author} eq 'tester');
ok ($data->{12345678901235}->{body}->{less} eq 'less body2');
