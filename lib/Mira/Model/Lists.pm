package Mira::Model::Lists;
$Mira::Model::Lists::VERSION = '0.07';

use strict;
use warnings;
use 5.012;
use utf8;

sub lists {
  my $class= shift;
  my $self = shift;
  my $config = shift;

  my $fields = {};
  foreach my $floor (keys %$config)
  {
    if ($config->{$floor}->{lists})
    {
      my @data = @{$config->{$floor}->{lists}};
      foreach my $field (@data)
      {
        $fields->{$floor}->{$field} = 'list';
      }
    }
  }

  my $list = {};
  my @month_names = qw(January February March April May June July August September October November December);
  my @jmonth_names = qw(فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند);

  foreach my $utid (keys %$self)
  {
    my $floor = $self->{$utid}->{floor};

    if (defined $self->{$utid}->{date} and $fields->{$floor}->{date} eq 'list')
    {
      my $date_field = $self->{$utid}->{date};
      if ($date_field =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
      {
        my $year = $self->{$utid}->{_spec}->{year};
        my $month = $self->{$utid}->{_spec}->{month};
        push @{ $list->{$floor}->{date}->{"$year$month"}->{posts} }, $utid;

        $list->{$floor}->{date}->{"$year$month"}->{name} = "$month_names[$month-1] $year";
        $list->{$floor}->{date}->{"$year$month"}->{_year} = $year;
        $list->{$floor}->{date}->{"$year$month"}->{year} = $year;
        $list->{$floor}->{date}->{"$year$month"}->{_month} = $month;
        $list->{$floor}->{date}->{"$year$month"}->{month} = $month;
        $list->{$floor}->{date}->{"$year$month"}->{number} = "$year - $month";
        $list->{$floor}->{date}->{"$year$month"}->{_number} = "$year$month";
        $list->{$floor}->{date}->{"$year$month"}->{url} =
        "$config->{$floor}->{root}/archive/".
        "$year/$month/";
        $list->{$floor}->{date}->{"$year$month"}->{url} =~ s{(?<!http:)/+}{/}g;
      }
    }

    if ($config->{$floor}->{'date_format'} and $config->{$floor}->{'date_format'} eq 'jalali' and defined $self->{$utid}->{jdate} and $fields->{$floor}->{jdate} eq 'list')
    {
      my $date_field = $self->{$utid}->{jdate};
      if ($date_field =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
      {
        my $year = $self->{$utid}->{_spec}->{jyear};
        my $month = $self->{$utid}->{_spec}->{jmonth};
        push @{ $list->{$floor}->{jdate}->{"$year$month"}->{posts} }, $utid;

        $list->{$floor}->{jdate}->{"$year$month"}->{name} = "$jmonth_names[$month-1] $year";
        $list->{$floor}->{jdate}->{"$year$month"}->{name} =~ tr/1234567890/۱۲۳۴۵۶۷۸۹۰/;
        $list->{$floor}->{jdate}->{"$year$month"}->{_year} = $year;
        $list->{$floor}->{jdate}->{"$year$month"}->{year} = $year;
        $list->{$floor}->{jdate}->{"$year$month"}->{_month} = $month;
        $list->{$floor}->{jdate}->{"$year$month"}->{month} = $month;
        $list->{$floor}->{jdate}->{"$year$month"}->{number} = "$year - $month";
        $list->{$floor}->{jdate}->{"$year$month"}->{_number} = "$year$month";
        $list->{$floor}->{jdate}->{"$year$month"}->{url} =
        "$config->{$floor}->{root}/archive/".
        "$year/$month/";
        $list->{$floor}->{jdate}->{"$year$month"}->{url} =~ s{(?<!http:)/+}{/}g;
      }
    }

    foreach my $field (keys %{$self->{$utid}})
    {
      ($field !~ /^(date|jdate)$/) || next;
      my @list_items;
      my @list_items_url;

      if (exists $fields->{$floor}->{$field})
      {
        if ($self->{$utid}->{$field} and ref($self->{$utid}->{$field}) eq "ARRAY")
        {
          @list_items = @{ $self->{$utid}->{$field} };
        } elsif ($self->{$utid}->{$field})
        {
          my $item = $self->{$utid}->{$field};
          push @list_items, $item;
        }

        $self->{$utid}->{$field} = {} if ($self->{$utid}->{$field});
	      @list_items = grep {$_} @list_items;
        @list_items_url = @list_items;
        @list_items_url = map {$_ =~ s/[^\w]/-/g; $_} @list_items_url;
        foreach my $i (0 .. $#list_items)
        {
          #TODO if $conf->{namescape}->{$list_items[$i]} {}
          $self->{$utid}->{$field}->{$list_items[$i]}->{name} = $list_items[$i];
          $list->{$floor}->{$field}->{$list_items[$i]}->{name} = $list_items[$i];
          push @{$list->{$floor}->{$field}->{$list_items[$i]}->{posts}}, $utid;
          if ($config->{$floor}->{namespace}->{$list_items[$i]})
          {
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} = $config->{$floor}->{namespace}->{$list_items[$i]};
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =~ s:[^\w]:-:g;
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =
            "$config->{$floor}->{root}/".
            "$field/".
            $self->{$utid}->{$field}->{$list_items[$i]}->{url}."/";
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =~ s{(?<!http:)/+}{/}g;
            $list->{$floor}->{$field}->{$list_items[$i]}->{url} = $self->{$utid}->{$field}->{$list_items[$i]}->{url};
          } else {
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =
            "$config->{$floor}->{root}/".
            "$field/".
            $list_items_url[$i]."/";
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =~ s{(?<!http:)/+}{/}g;
            $list->{$floor}->{$field}->{$list_items[$i]}->{url} = $self->{$utid}->{$field}->{$list_items[$i]}->{url};
          }
        }
      }
    }

  }

  return $list;
}

1;
