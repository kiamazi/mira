package Mira::Plugin::Date::Jalali;
$Mira::Plugin::Date::Jalali::VERSION = '00.07.37';

use strict;
use warnings;

use Carp;

use utf8;
use 5.012;


use Exporter 'import';
our @EXPORT_OK = qw(jalali gregorian);


#our %EXPORT_TAGS = ( 'all' => [ qw(jalali gregorian) ] );


my @g_days_in_month = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
my @j_days_in_month = (31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29);
my @j_month_name = ("", "Farvardin", "Ordibehesht", "Khordad", "Tir",
                      "Mordad", "Shahrivar", "Mehr", "Aban", "Azar",
                      "Dey", "Bahman", "Esfand");

sub new {
  my $class = shift;
  my %switches = @_;

  my $self = {};
  $self->{year} = $switches{year} ? $switches{year} : croak "meed year value";
  $self->{month} = $switches{month} ? $switches{month} : croak "meed month value";
  $self->{day} = $switches{day} ? $switches{day} : croak "meed day value";

  bless $self, $class;
  return $self;
}


sub jalali {
  my $self = shift;
  my $g_year = $self->{year} - 1600;
  my $g_month = $self->{month} - 1;
  my $g_day = $self->{day} - 1;

  my $i=0;

  my $g_day_no = 365*$g_year+int(($g_year+3)/4)-int(($g_year+99)/100)+int(($g_year+399)/400);

  for ($i=0; $i < $g_month; ++$i)
  {
    $g_day_no += $g_days_in_month[$i];
  }
  if ($g_month>1 && (($g_year%4==0 && $g_year%100!=0) || ($g_year%400==0)))
  {
  #leap and after Feb
  ++$g_day_no;
  }
  $g_day_no += $g_day;
  my $j_day_no = $g_day_no-79;
  my $j_np = int($j_day_no/12053);
  $j_day_no %= 12053;
  my $jalai_year = 979+33*$j_np+4*int($j_day_no/1461);
  $j_day_no %= 1461;
  if ($j_day_no >= 366)
  {
    $jalai_year += int(($j_day_no-1)/365);
    $j_day_no = ($j_day_no-1)%365;
  }
  for ($i = 0; $i < 11 && $j_day_no >= $j_days_in_month[$i]; ++$i)
  {
    $j_day_no -= $j_days_in_month[$i];
  }
  my $jalai_month = $i+1;
  my $jalali_day = $j_day_no+1;

  my $this = {};
  $this->{year} = $jalai_year;
  $this->{month} = $jalai_month;
  $this->{day} = $jalali_day;

  return $this;
}

sub gregorian {
  my $self = shift;
  my $j_year = $self->{year} - 979;
  my $j_month = $self->{month} - 1;
  my $j_day = $self->{day} - 1;



  my $i=0;
  my $j_day_no = 365*$j_year + int(($j_year/33))*8 + int(($j_year%33+3)/4);
  for ($i=0; $i < $j_month; ++$i)
  {
    $j_day_no += $j_days_in_month[$i];
  }
  $j_day_no += $j_day;
  my $g_day_no = $j_day_no+79;
  my $gy = 1600 + 400*int(($g_day_no/146097)); #/* 146097 = 365*400 + 400/4 - 400/100 + 400/400 */
  $g_day_no = $g_day_no % 146097;
  my $leap = 1;
  if ($g_day_no >= 36525) #/* 36525 = 365*100 + 100/4 */
  {
    $g_day_no--;
    $gy += 100*int(($g_day_no/36524)); #/* 36524 = 365*100 + 100/4 - 100/100 */
    $g_day_no = $g_day_no % 36524;
    if ($g_day_no >= 365)
    {
      $g_day_no++;
    } else
    {
      $leap = 0;
    }
  }
  $gy += 4*int(($g_day_no/1461)); #/* 1461 = 365*4 + 4/4 */
  $g_day_no %= 1461;
  if ($g_day_no >= 366)
  {
    $leap = 0;
    $g_day_no--;
    $gy += int($g_day_no/365);
    $g_day_no = $g_day_no % 365;
  }
  for ($i = 0; $g_day_no >= $g_days_in_month[$i] + ($i == 1 && $leap); $i++)
  {
    $g_day_no -= $g_days_in_month[$i] + ($i == 1 && $leap);
  }
  my $gm = $i+1;
  my $gd = $g_day_no+1;

  my $this = {};
  $this->{year} = $gy;
  $this->{month} = $gm;
  $this->{day} = $gd;

  return $this;
}



1;










__END__

=head1 NAME

Mira::Date::Jalali - Perl extension for converting Gregorian Dates and Jalali Date to each other

=head1 SYNOPSIS

  use Mira::Date::Jalali;
  my $date = Mira::Date::Jalali->new
  (
    year => 1395,
    month => 11,
    day => 12
  );
  $year = $date->gregorian->{year};   #2017
  $month = $date->gregorian->{month}; #1
  $day = $date->gregorian->{day};     #31



  use Mira::Date::Jalali;
  my $date = Mira::Date::Jalali->new
  (
    year => 2017,
    month => 1,
    day => 31
  );
  $year = $date->jalali->{year};   #1395
  $month = $date->jalali->{month}; #11
  $day = $date->jalali->{day};     #12

=head1 ABSTRACT

This module converts Gregorian date to Jalali and Jalali date to Gregorian.

=head1 DESCRIPTION

this module is a rewrite for Date::Jalali2 for use in mira
(mira is a content manager framework)


=head2 EXPORT

gregorian

  use Mira::Date::Jalali;
  $gre_date = gregorian({
    year => 1395,
    month => 11,
    day => 12
  });
  print $gre_date->{year};       #2017


jalali

  use Mira::Date::Jalali;
  $jal_date = jalali({
    year => 2017,
    month => 1,
    day => 31
  });
  print $jal_date->{year};       #1395

=head1 SEE ALSO

Date::jalali2

=head1 CHANGE LOG

add export itemsq

separate methods

=head1 AUTHOR

kiamazi C<kiavash@cpan.org>

Redistributed by : Ehsan Golpayegani <http://www.golpayegani.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2017 by Kiavash

The original algorithm was written with regards to Gregorian<->Jalali
convertor developed by Roozbeh Pournader and Mohammad Toossi
available at:

http://www.farsiweb.info/jalali/jalali.c

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
