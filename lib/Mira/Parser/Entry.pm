package Mira::Parser::Entry;

use strict;
use warnings;
use utf8;
use 5.012;
use YAML;
use Carp;

use Mira;

sub parse {
  my $class = shift;
  my $self = {};
  my %switches = @_;

  my $entry = $switches{entry} or croak "entry parser need entry field";
  my $floor = $switches{floor} or croak "entry parser need floor field";

  my @month_names = qw(January February March April May June July August September October November December);
  my @jmonth_names = qw(فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند);

  my $content;
  my $utid;
  {
    open my $fh, '<:encoding(UTF-8)', $entry or die $!;
    local $/ = undef;
    $content = <$fh>;
    close $fh;
  }

#  $content =~ s/^---+/---/mg;


  if ($content =~
  m/
    ^---\s*
    (?<detail>[\w\W]+?)
    ^---\s*
    (?<body>[\w\W]*)
  $/mx)
  {
    my $detail = $+{detail};
    my $body = $+{body};
    $detail =~ s/\s*(?<!\\)#.*//g;
    $detail =~ s/(?<!\\)\\#/#/g;
    $detail =~ s/\\\\#/\\#/g;
    $body =~ s/\n\s*$//;
    if ($detail =~ /^\s*utid\s*:(?<utid>.*)$/m)
    {
      my $top;
      eval
      {
        $top = Load($detail);
      }; if ($@)
      {
        say "problem in YAML details:
        $entry";
        return;
      }
      $utid = delete $top->{utid};
#      $utid = $+{utid};
#      $utid =~ s/^\s*(.*)\s*$/$1/g;
      $utid =~ s/[^\d]//g;

      $self->{utid} = $utid;

      $self->{values}->{_spec}->{file_address} = $entry;

      @{$self->{values}}{keys %$top} = values %$top;

      if (exists $top->{date})
      {
        if ($top->{date} =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})([ T](?<hour>\d{1,2}):(?<minute>\d{1,2}):(?<second>\d{1,2}))?$/)
        {
          my ($year, $month, $day, $hour, $minute, $second) = ($+{year}, $+{month}, $+{day}, $+{hour}, $+{minute}, $+{second});
          $self->{values}->{_spec}->{year} = sprintf "%04d", $year;

          $self->{values}->{_spec}->{month} = sprintf "%02d", $month;
          say "$self->{values}->{_spec}->{file_address}\'s Month number is biger than 12 >> $month, for this build Mira use 12 for post month number, but plz fix it" if ($month > 12);
          $self->{values}->{_spec}->{month} = 12 if ($month > 12);

          $self->{values}->{_spec}->{day} = sprintf "%02d", $day;
          say "$self->{values}->{_spec}->{file_address}\'s Day number is biger than 31 >> $day, for this build Mira use 31 for post day number, but plz fix it" if ($day > 31);
          $self->{values}->{_spec}->{day} = 31 if ($day > 31);

          $self->{values}->{_spec}->{hour} = sprintf "%02d", $hour;
          say "$self->{values}->{_spec}->{file_address}\'s hour is biger than 23 >> $hour, for this build Mira use 00 for post hour, but plz fix it" if ($hour > 23);
          $self->{values}->{_spec}->{hour} = 24 if ($day > 24);

          $self->{values}->{_spec}->{minute} = sprintf "%02d", $minute;
          say "$self->{values}->{_spec}->{file_address}\'s minute number is biger than 59 >> $minute, for this build Mira use 59 for post minute, but plz fix it" if ($minute > 59);
          $self->{values}->{_spec}->{minute} = 31 if ($day > 31);

          $self->{values}->{_spec}->{second} = sprintf "%02d", $second;
          say "$self->{values}->{_spec}->{file_address}\'s second number is biger than 59 >> $second, for this build Mira use 59 for your post second, but plz fix it" if ($second > 59);
          $self->{values}->{_spec}->{second} = 31 if ($day > 31);

          $self->{values}->{CALENDAR}->{year} = $self->{values}->{_spec}->{year};
          $self->{values}->{CALENDAR}->{month} = $self->{values}->{_spec}->{month};
          $self->{values}->{CALENDAR}->{month_name} = $month_names[$month-1];
          $self->{values}->{CALENDAR}->{day} = $self->{values}->{_spec}->{day};

          if (not exists $top->{jdate})
          {
            my $date = Mira::Date::Jalali->new
            (
              year => $year,
              month => $month,
              day => $day
            );
            $self->{values}->{_spec}->{jyear} = sprintf "%04d", $date->jalali->{year};
            $self->{values}->{_spec}->{jmonth} = sprintf "%02d", $date->jalali->{month};
            $self->{values}->{_spec}->{jday} = sprintf "%02d", $date->jalali->{day};
            $self->{values}->{CALENDAR}->{jyear} = $self->{values}->{_spec}->{jyear};
            $self->{values}->{CALENDAR}->{jmonth} = $self->{values}->{_spec}->{jmonth};
            my $jmonth = $self->{values}->{CALENDAR}->{jmonth};
            $self->{values}->{CALENDAR}->{jmonth_name} = $jmonth_names[$jmonth-1];
            $self->{values}->{CALENDAR}->{jday} = $self->{values}->{_spec}->{jday};
          }
        } else
        {
          say "$self->{values}->{_spec}->{file_address} date format is unvalid, plz fix it";
        }
      }
      if (exists $top->{jdate} and $top->{jdate} =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
      {
        $self->{values}->{_spec}->{jyear} = sprintf "%04d", $+{year};
        $self->{values}->{_spec}->{jmonth} = sprintf "%02d", $+{month};
        $self->{values}->{_spec}->{jday} = sprintf "%02d", $+{day};
        $self->{values}->{CALENDAR}->{jyear} = $self->{values}->{_spec}->{jyear};
        $self->{values}->{CALENDAR}->{jmonth} = $self->{values}->{_spec}->{jmonth};
        $self->{values}->{CALENDAR}->{jday} = $self->{values}->{_spec}->{jday};
      }

      $self->{values}->{floor} = $floor;
      $self->{values}->{body} = $body;
      $self->{values}->{title} = $utid unless $self->{values}->{title};
    }
  }

  #bless $self, $class;
  return $self;
}


1;
