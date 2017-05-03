package Mira::Model::Archive;
$Mira::Model::Archive::VERSION = '00.07.45';

use strict;
use warnings;
use 5.012;
use utf8;

use DateTime;

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
    my $archive = {};

    my @month_names = qw(January February March April May June July August September October November December);
    #my @jmonth_names = qw(فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند);

    foreach my $utid (keys %$self)
    {
        my $floor = $self->{$utid}->{floor};
        $archive->{$floor}->{date} = {} if not $archive->{$floor}->{date};
        $archive->{$floor}->{list} = {} if not $archive->{$floor}->{list};

        if (
            defined $self->{$utid}->{date}
            and
            defined $fields->{$floor}->{date}
            and
            $fields->{$floor}->{date} eq 'list'
          )
        {
            my $date_field = $self->{$utid}->{date};
            if ($date_field =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
            {
                my $year = $self->{$utid}->{_spec}->{year};
                my $month = $self->{$utid}->{_spec}->{month};
                push @{ $archive->{$floor}->{date}->{date}->{"$year$month"}->{posts} }, $utid;

                $archive->{$floor}->{date}->{date}->{"$year$month"}->{name} =
                    $month_names[$month-1]." ".$year;
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{_year} = $year;
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{year} = $year;
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{_month} = $month;
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{month} = $month;
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{month_name} =
                    $month_names[$month-1];
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{number} =
                    $year.$month;
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{_number} =
                    $year.$month;
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{url} =
                    $config->{$floor}->{root}."/archive/".$year."/".$month."/";
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{url} =~ s{(?<!http:)/+}{/}g;
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{furl} =
                    $config->{$floor}->{url}
                    ."/archive/"
                    .$year
                    ."/"
                    .$month
                    ."/";
                $archive->{$floor}->{date}->{date}->{"$year$month"}->{furl} =~ s{(?<!http:)/+}{/}g;

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

                $self->{$utid}->{$field} = [] if ($self->{$utid}->{$field});
	               @list_items = grep {$_} @list_items;
                   @list_items_url = @list_items;
                   @list_items_url = map {$_ =~ s/[^\w]/-/g; $_} @list_items_url;
                   foreach my $i (0 .. $#list_items)
                   {
                       #TODO if $conf->{namescape}->{$list_items[$i]} {}
                       $self->{$utid}->{$field}->[$i]->{name} = $list_items[$i];
                       $archive->{$floor}->{list}->{$field}->{$list_items[$i]}->{name} = $list_items[$i];
                       push @{$archive->{$floor}->{list}->{$field}->{$list_items[$i]}->{posts}}, $utid;
                       if ($config->{$floor}->{namespace}->{$list_items[$i]})
                       {
                           $self->{$utid}->{$field}->[$i]->{showname} = $config->{$floor}->{namespace}->{$list_items[$i]};
                           $archive->{$floor}->{list}->{$field}->{$list_items[$i]}->{showname} = $config->{$floor}->{namespace}->{$list_items[$i]};
                           $self->{$utid}->{$field}->[$i]->{url} = $config->{$floor}->{namespace}->{$list_items[$i]};
                           $self->{$utid}->{$field}->[$i]->{url} =~ s:[^\w]:-:g;
                           $self->{$utid}->{$field}->[$i]->{url} =
                           "$config->{$floor}->{root}/".
                           "$field/".
                           $self->{$utid}->{$field}->[$i]->{url}."/";
                           $self->{$utid}->{$field}->[$i]->{url} =~ s{(?<!http:)/+}{/}g;
                       } else
                       {
                           $self->{$utid}->{$field}->[$i]->{showname} = $list_items[$i];
                           $archive->{$floor}->{list}->{$field}->{$list_items[$i]}->{showname} = $list_items[$i];
                           $self->{$utid}->{$field}->[$i]->{url} =
                           "$config->{$floor}->{root}/".
                           "$field/".
                           $list_items_url[$i]."/";
                           $self->{$utid}->{$field}->[$i]->{url} =~ s{(?<!http:)/+}{/}g;
                       }
                       $self->{$utid}->{$field}->[$i]->{furl} = $self->{$utid}->{$field}->[$i]->{url};
                       my $baseurl = $config->{$floor}->{root};
                       my $furl =qr{^$baseurl};
                       my $fpath = $config->{$floor}->{url};
                       $self->{$utid}->{$field}->[$i]->{furl} =~ s/$furl/$fpath/ if $config->{$floor}->{root};

                       $archive->{$floor}->{list}->{$field}->{$list_items[$i]}->{url} = $self->{$utid}->{$field}->[$i]->{url};
                       $archive->{$floor}->{list}->{$field}->{$list_items[$i]}->{furl} = $self->{$utid}->{$field}->[$i]->{furl};
                   }
               }
           }
           #####here
       }

  return $archive;
}

1;
