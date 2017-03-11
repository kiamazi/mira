package Mira::Plugin::Jdate;
$Mira::Plugin::JDate::VERSION = '00.07.22';

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
        }
        elsif ( exists $data->{$utid}->{jdate}
            and $data->{$utid}->{jdate} =~
            /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/ )
        {
            my ( $year, $month, $day ) = ( $+{year}, $+{month}, $+{day} );
            my $date = Mira::Date::Jalali->new(
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
        }

        my $list_test;
        if ( $config->{lists} ) {
            foreach my $list ( @{ $config->{lists} } ) {
                $list_test = 'list' if $list eq 'jdate';
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
