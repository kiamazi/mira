package Mira::Control::Content::Date;
$Mira::Control::Content::Date::VERSION = '00.07.56';

use strict;
use warnings;
use 5.012;

use DateTime;

sub date {
    my $class    = shift;
    my $values   = shift;
    my $timezone = shift;

    my $mn;
    if ($timezone =~ m/^([+-])/) {$mn = $1};
    $mn = '+' unless $mn;
    $timezone =~ s/[^\d]//g;
    $timezone = sprintf "%04d", $timezone;

    my ($year, $month, $day, $hour, $minute, $second) =
      qw('0000' '00' '00' '00' '00' '00');

    if (exists $values->{date})
    {
        if ($values->{date} =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})(?:[ T](?<hour>\d{1,2}):(?<minute>\d{1,2}):(?<second>\d{1,2}))?$/)
        {
            ($year, $month, $day, $hour, $minute, $second) =
               ($+{year}, $+{month}, $+{day}, $+{hour}, $+{minute}, $+{second});
        } elsif ( $values->{date} =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/ )
        {
            ($year, $month, $day) = ($+{year}, $+{month}, $+{day});
        } else
        {
            say "$values->{SPEC}->{file_address} date format is unvalid, plz fix it:
            'YYYY-MM-DD HH:MM:SS' or 'YYYY-MM-DDTHH:MM:SS' or 'YYYY-MM-DD'";
            return;
        }
        $year = sprintf "%04d", $year;

        $month = sprintf "%02d", $month;
        $month = ($month % 12) ? ($month % 12) : '12'  if ($month > 12)
          and say " > $values->{SPEC}->{file_address} ~> Month > 12";

        $day = sprintf "%02d", $day;
        $day = ($day % 31) ? ($day % 31) : '31' if ($day > 31)
          and say " > $values->{SPEC}->{file_address} ~> Day > 31";;

        $hour = sprintf "%02d", $hour;
        $hour = ($hour % 23) ? ($hour % 23) : '23' if ($hour > 23)
          and say " > $values->{SPEC}->{file_address} ~> Hour > 23";;

        $minute = sprintf "%02d", $minute;
        $minute = ($minute % 59) ? ($minute % 59) : '59' if ($minute > 59)
          and say " > $values->{SPEC}->{file_address} ~> Minute > 59";;

        $second = sprintf "%02d", $second;
        $second = ($second % 59) ? ($second % 59) : '59' if ($second > 59)
          and say " > $values->{SPEC}->{file_address} ~> Decond > 59";;

        my $date_time = DateTime->new(
            year       => $year,
            month      => $month,
            day        => $day,
        );
        my $month_name  = $date_time->month_name;
        my $month_abbr  = $date_time->month_abbr;
        my $day_name    = $date_time->day_name;
        my $day_abbr    = $date_time->day_abbr;

        $values->{CALENDAR}->{year} = $year;
        $values->{CALENDAR}->{month} = $month;
        $values->{CALENDAR}->{month_name} = $month_name;
        $values->{CALENDAR}->{month_abbr} = $month_abbr;
        $values->{CALENDAR}->{day} = $day;
        $values->{CALENDAR}->{day_name} = $day_name;
        $values->{CALENDAR}->{day_abbr} = $day_abbr;
        $values->{CALENDAR}->{hour} = $hour;
        $values->{CALENDAR}->{minute} = $minute;
        $values->{CALENDAR}->{second} = $second;
        $values->{CALENDAR}->{date} =
        "$year-$month-$day" . 'T' . "$hour:$minute:$second" . $mn . $timezone;
    }
}

1;
