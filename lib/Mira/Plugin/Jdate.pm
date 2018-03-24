package Mira::Plugin::Jdate;
$Mira::Plugin::Jdate::VERSION = '00.07.52';

use strict;
use warnings;
use 5.012;

use utf8;

use Mira::Plugin;

use DateTime;
use Mira::Plugin::Date::Jalali;

sub plug {
    my $class  = shift;
    my $plugin = shift;

    my $data          = $plugin->get_data_base;
    my $date_archives = $plugin->get_date_archives;
    my $config        = $plugin->get_site_config;

    my @jmonth_names =
      qw(فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند);
    my @jday_names =
      qw(دوشنبه سه‌شنبه‌ چهارشنبه پنج‌شنبه جمعه شنبه یک‌شنبه);

    foreach my $utid ( keys %$data ) {
        if ( not exists $data->{$utid}->{jdate} ) {
            if ( exists $data->{$utid}->{date}
                and $data->{$utid}->{date} =~
                /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/ )
            {
                my ( $year, $month, $day ) = ( $+{year}, $+{month}, $+{day} );
                my $date = Mira::Plugin::Date::Jalali->new(
                    year  => $year,
                    month => $month,
                    day   => $day
                );
                $data->{$utid}->{_spec}->{jyear} = sprintf "%04d",
                  $date->jalali->{year};
                $data->{$utid}->{_spec}->{jmonth} = sprintf "%02d",
                  $date->jalali->{month};
                $data->{$utid}->{_spec}->{jday} = sprintf "%02d",
                  $date->jalali->{day};

                my $date_time = DateTime->new(
                    year  => $year,
                    month => $month,
                    day   => $day,
                );
                my $dow = $date_time->day_of_week;

                $data->{$utid}->{CALENDAR}->{jyear} =
                  $data->{$utid}->{_spec}->{jyear};
                $data->{$utid}->{CALENDAR}->{jmonth} =
                  $data->{$utid}->{_spec}->{jmonth};
                my $jmonth = $data->{$utid}->{CALENDAR}->{jmonth};
                $data->{$utid}->{CALENDAR}->{jmonth_name} =
                  $jmonth_names[ $jmonth - 1 ];
                $data->{$utid}->{CALENDAR}->{jday} =
                  $data->{$utid}->{_spec}->{jday};
                $data->{$utid}->{CALENDAR}->{jday_name} =
                  $jday_names[ $dow - 1 ];
                $data->{$utid}->{jdate} =
                    $data->{$utid}->{_spec}->{jyear} . "-"
                  . $data->{$utid}->{_spec}->{jmonth} . "-"
                  . $data->{$utid}->{_spec}->{jday};
            }
        } elsif ( exists $data->{$utid}->{jdate}
            and $data->{$utid}->{jdate} =~
            /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/ )
        {
            my ( $year, $month, $day ) = ( $+{year}, $+{month}, $+{day} );
            my $date = Mira::Plugin::Date::Jalali->new(
                year  => $year,
                month => $month,
                day   => $day
            );
            my $date_time = DateTime->new(
                year  => $date->gregorian->{year},
                month => $date->gregorian->{month},
                day   => $date->gregorian->{day},
            );
            my $dow = $date_time->day_of_week;

            $data->{$utid}->{_spec}->{jyear}  = sprintf "%04d", $year;
            $data->{$utid}->{_spec}->{jmonth} = sprintf "%02d", $month;
            $data->{$utid}->{_spec}->{jday}   = sprintf "%02d", $day;
            $data->{$utid}->{CALENDAR}->{jyear} =
              $data->{$utid}->{_spec}->{jyear};
            $data->{$utid}->{CALENDAR}->{jmonth} =
              $data->{$utid}->{_spec}->{jmonth};
            my $jmonth = $data->{$utid}->{CALENDAR}->{jmonth};
            $data->{$utid}->{CALENDAR}->{jmonth_name} =
              $jmonth_names[ $jmonth - 1 ];
            $data->{$utid}->{CALENDAR}->{jday} =
              $data->{$utid}->{_spec}->{jday};
            $data->{$utid}->{CALENDAR}->{jday_name} = $jday_names[ $dow - 1 ];

            if (not exists $data->{$utid}->{date}) {
                my $month_name  = $date_time->month_name;
                my $month_abbr  = $date_time->month_abbr;
                my $day_name    = $date_time->day_name;
                my $day_abbr    = $date_time->day_abbr;

                $data->{$utid}->{CALENDAR}->{year} =
                    sprintf "%04d", $date->gregorian->{year};
                $data->{$utid}->{CALENDAR}->{month} =
                    sprintf "%02d", $date->gregorian->{month};
                $data->{$utid}->{CALENDAR}->{month_name} = $month_name;
                $data->{$utid}->{CALENDAR}->{month_abbr} = $month_abbr;
                $data->{$utid}->{CALENDAR}->{day} =
                    sprintf "%02d", $date->gregorian->{day};
                $data->{$utid}->{CALENDAR}->{day_name} = $day_name;
                $data->{$utid}->{CALENDAR}->{day_abbr} = $day_abbr;
                $data->{$utid}->{date} =
                    $data->{$utid}->{CALENDAR}->{year} . "-"
                  . $data->{$utid}->{CALENDAR}->{month} . "-"
                  . $data->{$utid}->{CALENDAR}->{day};
            }
        }

        my $list_test;
        if ( $config->{lists} ) {
            foreach my $list ( @{ $config->{lists} } ) {
                $list_test = 'list' if $list =~ /^jdate$/i;
            }
        }

        if ( defined $data->{$utid}->{jdate}
            and $list_test
            and $list_test eq 'list' )
        {
            my $date_field = $data->{$utid}->{jdate};
            if ( $date_field =~
                /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/ )
            {
                my $year  = $data->{$utid}->{_spec}->{jyear};
                my $month = $data->{$utid}->{_spec}->{jmonth};
                push @{ $date_archives->{jdate}->{"$year$month"}
                      ->{posts} }, $utid;

                $date_archives->{jdate}->{"$year$month"}->{name} =
                  "$jmonth_names[$month-1] $year";
                $date_archives->{jdate}->{"$year$month"}->{name} =~
                  tr/1234567890/۱۲۳۴۵۶۷۸۹۰/;
                $date_archives->{jdate}->{"$year$month"}->{_year} =
                  $year;
                $date_archives->{jdate}->{"$year$month"}->{year} =
                  $year;
                $date_archives->{jdate}->{"$year$month"}->{_month}
                  = $month;
                $date_archives->{jdate}->{"$year$month"}->{month} =
                  $month;
                $date_archives->{jdate}->{"$year$month"}->{month_name} =
                  $jmonth_names[$month-1];
                $date_archives->{jdate}->{"$year$month"}->{number}
                  = "$year - $month";
                $date_archives->{jdate}->{"$year$month"}->{_number}
                  = "$year$month";
                $date_archives->{jdate}->{"$year$month"}->{url} =
                  "$config->{root}/archive/" . "$year/$month/";
                $date_archives->{jdate}->{"$year$month"}->{url} =~
                  s{(?<!http:)/+}{/}g;
            }
        }

    }

}

1;
