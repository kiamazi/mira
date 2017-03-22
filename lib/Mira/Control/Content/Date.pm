package Mira::Control::Content::Date;
$Mira::Control::Content::Date::VERSION = '00.07.29';

use strict;
use warnings;
use 5.012;

use DateTime;

sub date {
  my $class = shift;
  my $values = shift;

  #my @month_names = qw(January February March April May June July August September October November December);

  if (exists $values->{date})
  {
    if ($values->{date} =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})([ T](?<hour>\d{1,2}):(?<minute>\d{1,2}):(?<second>\d{1,2}))?$/)
    {
      my ($year, $month, $day, $hour, $minute, $second) = ($+{year}, $+{month}, $+{day}, $+{hour}, $+{minute}, $+{second});
      $values->{_spec}->{year} = sprintf "%04d", $year;

      $values->{_spec}->{month} = sprintf "%02d", $month;
      say "$values->{_spec}->{file_address}\'s Month number is biger than 12 >> $month, for this build Mira use 12 for post month number, but plz fix it" if ($month > 12);
      $values->{_spec}->{month} = 12 if ($month > 12);

      $values->{_spec}->{day} = sprintf "%02d", $day;
      say "$values->{_spec}->{file_address}\'s Day number is biger than 31 >> $day, for this build Mira use 31 for post day number, but plz fix it" if ($day > 31);
      $values->{_spec}->{day} = 31 if ($day > 31);

      $values->{_spec}->{hour} = sprintf "%02d", $hour;
      say "$values->{_spec}->{file_address}\'s hour is biger than 23 >> $hour, for this build Mira use 00 for post hour, but plz fix it" if ($hour > 23);
      $values->{_spec}->{hour} = 24 if ($day > 24);

      $values->{_spec}->{minute} = sprintf "%02d", $minute;
      say "$values->{_spec}->{file_address}\'s minute number is biger than 59 >> $minute, for this build Mira use 59 for post minute, but plz fix it" if ($minute > 59);
      $values->{_spec}->{minute} = 31 if ($day > 31);

      $values->{_spec}->{second} = sprintf "%02d", $second;
      say "$values->{_spec}->{file_address}\'s second number is biger than 59 >> $second, for this build Mira use 59 for your post second, but plz fix it" if ($second > 59);
      $values->{_spec}->{second} = 31 if ($day > 31);

      my $date_time = DateTime->new(
        year       => $year,
        month      => $month,
        day        => $day,
      );
      my $month_name  = $date_time->month_name;
      my $month_abbr  = $date_time->month_abbr;
      my $day_name    = $date_time->day_name;
      my $day_abbr    = $date_time->day_abbr;

      $values->{CALENDAR}->{year} = $values->{_spec}->{year};
      $values->{CALENDAR}->{month} = $values->{_spec}->{month};
      #$values->{CALENDAR}->{month_name} = $month_names[$month-1];
      $values->{CALENDAR}->{month_name} = $month_name;
      $values->{CALENDAR}->{month_abbr} = $month_abbr;
      $values->{CALENDAR}->{day} = $values->{_spec}->{day};
      $values->{CALENDAR}->{day_name} = $day_name;
      $values->{CALENDAR}->{day_abbr} = $day_abbr;
      $values->{CALENDAR}->{hour} = $values->{_spec}->{hour};
      $values->{CALENDAR}->{minute} = $values->{_spec}->{minute};
      $values->{CALENDAR}->{second} = $values->{_spec}->{second};

    } else
    {
      say "$values->{_spec}->{file_address} date format is unvalid, plz fix it 'YYYY-MM-DD HH:MM:SS'";
    }
#TODO move this part to hdate plugin:
#  } elsif (exists $values->{jdate} and $values->{jdate} =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
#  {
#    my ($year, $month, $day) = ($+{year}, $+{month}, $+{day});
#    my $date = Mira::Date::Jalali->new
#    (
#      year => $year,
#      month => $month,
#      day => $day
#    );
#
#    my $date_time = DateTime->new(
#      year       => $date->gregorian->{year},
#      month      => $date->gregorian->{month},
#      day        => $date->gregorian->{day},
#    );
#    my $month_name  = $date_time->month_name;
#    my $month_abbr  = $date_time->month_abbr;
#    my $day_name    = $date_time->day_name;
#    my $day_abbr    = $date_time->day_abbr;
#
#    $values->{_spec}->{year} = sprintf "%04d", $date->gregorian->{year};
#    $values->{_spec}->{month} = sprintf "%02d", $date->gregorian->{month};
#    $values->{_spec}->{day} = sprintf "%02d", $date->gregorian->{day};
#    $values->{CALENDAR}->{year} = $values->{_spec}->{year};
#    $values->{CALENDAR}->{month} = $values->{_spec}->{month};
#    #$values->{CALENDAR}->{month_name} = $month_names[$month-1];
#    $values->{CALENDAR}->{month_name} = $month_name;
#    $values->{CALENDAR}->{month_abbr} = $month_abbr;
#    $values->{CALENDAR}->{day} = $values->{_spec}->{day};
#    $values->{CALENDAR}->{day_name} = $day_name;
#    $values->{CALENDAR}->{day_abbr} = $day_abbr;
  }

}

1;
