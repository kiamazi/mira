package Mira::Control::Jdate;
$Mira::Control::Jdate::VERSION = '0.07';

use strict;
use warnings;
use 5.012;
use utf8;

use Mira::Date::Jalali;

sub jdate {
  my $class = shift;

  my $values = shift;

  my @jmonth_names = qw(فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند);
  my @jday_names = qw(شنبه یک‌شنبه دوشنبه سه‌شنبه چهارشنبه پنج‌شنبه جمعه);

  if (not exists $values->{jdate})
  {
    if (exists $values->{date} and $values->{date} =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
    {
      my ($year, $month, $day) = ($+{year}, $+{month}, $+{day});
      my $date = Mira::Date::Jalali->new
      (
        year  => $year,
        month => $month,
        day   => $day
      );
      $values->{_spec}->{jyear} = sprintf "%04d", $date->jalali->{year};
      $values->{_spec}->{jmonth} = sprintf "%02d", $date->jalali->{month};
      $values->{_spec}->{jday} = sprintf "%02d", $date->jalali->{day};

      my $date_time = DateTime->new(
        year       => $year,
        month      => $month,
        day        => $day,
      );
      my $dow = $date_time->day_of_week;

      $values->{CALENDAR}->{jyear} = $values->{_spec}->{jyear};
      $values->{CALENDAR}->{jmonth} = $values->{_spec}->{jmonth};
      my $jmonth = $values->{CALENDAR}->{jmonth};
      $values->{CALENDAR}->{jmonth_name} = $jmonth_names[$jmonth-1];
      $values->{CALENDAR}->{jday} = $values->{_spec}->{jday};
      $values->{CALENDAR}->{jday_name} = $jday_names[$dow-1];
      $values->{jdate} =
        $values->{_spec}->{jyear}."-".
        $values->{_spec}->{jmonth}."-".
        $values->{_spec}->{jday};
    }
  } elsif (exists $values->{jdate} and $values->{jdate} =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
  {
    my ($year, $month, $day) = ($+{year}, $+{month}, $+{day});
    my $date = Mira::Date::Jalali->new
    (
      year  => $year,
      month => $month,
      day   => $day
    );
    my $date_time = DateTime->new(
      year       => $date->gregorian->{year},
      month      => $date->gregorian->{month},
      day        => $date->gregorian->{day},
    );
    my $dow = $date_time->day_of_week;

    $values->{_spec}->{jyear} = sprintf "%04d", $year;
    $values->{_spec}->{jmonth} = sprintf "%02d", $month;
    $values->{_spec}->{jday} = sprintf "%02d", $day;
    $values->{CALENDAR}->{jyear} = $values->{_spec}->{jyear};
    $values->{CALENDAR}->{jmonth} = $values->{_spec}->{jmonth};
    my $jmonth = $values->{CALENDAR}->{jmonth};
    $values->{CALENDAR}->{jmonth_name} = $jmonth_names[$jmonth-1];
    $values->{CALENDAR}->{jday} = $values->{_spec}->{jday};
    $values->{CALENDAR}->{jday_name} = $jday_names[$dow-1];
  }

}

1;
