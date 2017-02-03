package Mira::Data;

use strict;
use warnings;

use File::Spec::Functions;
use File::Basename qw/basename/;
use Carp;
use Encode;
use Encode::Locale;

use Mira;

use utf8;
use 5.012;

sub new {
  my $class = shift;
  my %switches = @_;

  my $source = $switches{source} if $switches{source};
  my $config = $switches{config};

  my $imgurl;

  my $self = {};

  my $glob = catfile($source, 'content', '*');

  my @content_directory_list = glob encode(locale_fs => $glob); # <"$addr/*">;
  @content_directory_list = grep {-d} @content_directory_list;
  #my @_floors = map {$1 if (m:$source/content/(.*)$:)} @content_directory_list;
  my @_floors = map {decode(locale_fs => basename($_))} @content_directory_list;
  foreach my $floor (@_floors)
  {
    my $glob = catfile($source, 'content', $floor , '*.pen');
    my @_entries = glob encode(locale_fs => $glob);

    foreach my $entry (@_entries)
    {
      $entry = decode(locale_fs => $entry);
      my $parser = Mira::Parser::Entry->parse(entry => $entry, floor => $floor);
      next unless $parser;
      my $utid = $parser->{utid};
      if (exists $self->{$utid})
      {
        say " # - $self->{$utid}->{_spec}->{file_address} and $entry have same utid($utid), please fix it";
      }
      $self->{$utid} = $parser->{values};

      if ($config->{$floor}->{date_format} and $config->{$floor}->{date_format} eq 'jalali' and not exists $self->{$utid}->{jdate})
      {
        $self->{$utid}->{jdate} =
          $self->{$utid}->{_spec}->{jyear}
          ."-".
          $self->{$utid}->{_spec}->{jmonth}
          ."-".
          $self->{$utid}->{_spec}->{jday};
      }

      if ($config->{$floor} and $config->{$floor}->{imageurl})
      {
        if ($config->{$floor}->{root})
        {
          $imgurl = "/$config->{$floor}->{root}/$config->{$floor}->{imageurl}";
        }
        else
        {
          $imgurl = "/$floor/$config->{$floor}->{imageurl}";
        }
      } elsif ($config->{_default}->{imageurl})
      {
        if ($config->{$floor}->{root})
        {
          $imgurl = "/$config->{$floor}->{root}/$config->{_default}->{imageurl}";
        } else {
          $imgurl = "/$floor/$config->{_default}->{imageurl}";
        }
      } else
      {
        $imgurl = "/$floor/static/img/";
      }
      $imgurl =~ s:/+:/:g;
      $self->{$utid}->{body} = Mira::Parser::img->replace($self->{$utid}->{body}, $imgurl);

      my $markup_lang = _markup_lang($self->{$utid}, $config);
      $self->{$utid}->{body} = Mira::Parser::Markup->markup(
                                $self->{$utid}->{body},
                                $self->{$utid}->{title},
                                $floor,
                                $markup_lang,
                                );
    }

  }

  _makeup($self, $config);

  bless $self, $class;
  return $self;
}



sub _markup_lang {

  my $post = shift;
  my $config = shift;

  my $floor = $post->{floor};

  my $markup_lang;

  if ($post->{'body-format'} and $post->{'body-format'} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i)
  {
    $markup_lang = $post->{'body-format'};
  } elsif (
    $config->{$floor} and
    $config->{$floor}->{default_body_format} and
    $config->{$floor}->{default_body_format} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i
    )
  {
    $markup_lang = $config->{$floor}->{default_body_format};
  } elsif (
    $config->{_default}->{default_body_format} and
    $config->{_default}->{default_body_format} =~ /^(markdown|md|html|text|txt|bbcode|textile)$/i
    )
  {
    $markup_lang = $config->{_default}->{default_body_format};
  } else
  {
    $markup_lang = 'markdown';
  }
  $markup_lang = 'markdown' if $markup_lang eq 'md';
  return $markup_lang;
}




sub _makeup {
  my $self = shift;
  my $config = shift;

  my %addr;

  my @utid = keys %$self;
  @utid = sort @utid;
  foreach my $utid (@utid)
  {
    my $floor = $self->{$utid}->{floor};

    my $baseurl;
    if ($config->{$floor} and $config->{$floor}->{root})
    {
      $baseurl = $config->{$floor}->{root}
    } else
    {
      $baseurl = "/$floor"
    }

    my $permanent;
    if ($config->{$floor} and $config->{$floor}->{permalink})
    {
      $permanent = $config->{$floor}->{permalink};
    } elsif ($config->{_default}->{permalink})
    {
      $permanent = $config->{_default}->{permalink};
    } else
    {
      $permanent = ":year/:month/:title";
    }
    $permanent .= "/:title" if $permanent !~ /:title/;


####### make Address Field #######
    #my $floor = $self->{$utid}->{floor};

    my $permalink = $self->{$utid}->{_permalink} ? $self->{$utid}->{_permalink} : $permanent;
    $permalink .= "/:title" if $permalink !~ /:title/;
    $permalink =~ s:^/+::;

    $permalink =~ s/:year/$self->{$utid}->{_spec}->{year}/g if (defined $self->{$utid}->{_spec}->{year});
    $permalink =~ s/:month/$self->{$utid}->{_spec}->{month}/g if (defined $self->{$utid}->{_spec}->{month});
    $permalink =~ s/:day/$self->{$utid}->{_spec}->{day}/g if (defined $self->{$utid}->{_spec}->{day});
    $permalink =~ s/(:year|:month|:day)//g;
    my @permalink = split (m:/:, $permalink);
    @permalink = map {$_ =~ s/\W//g if $_ !~ m/:title/; $_} @permalink;
    #@permalink = grep {$_ =~ /(:year|:month|:day|:title)/} @permalink;
    $permalink = join ("/", $baseurl, @permalink, "");
    $permalink =~ s"(?<!http:)/+"/"g;

#    unless ($self->{$utid}->{_index})
#    {
      my $titr_address = $self->{$utid}->{_index} ? $self->{$utid}->{_index} : $self->{$utid}->{title};
      $titr_address =~ s/[^\w]+$//g;
      $titr_address = $utid if (! $titr_address);
      $titr_address =~ s/[^\w]+/-/g;
      my $url;
      my $address;
      $permalink =~ s/:title/$titr_address/g;
      $permalink =~ s/:title//g;
      if (defined $addr{$permalink})
      {
        my $num = 2;
        while (1)
        {
          my $new_permalink = "$permalink/$num";
          unless (exists $addr{$new_permalink})
          {
            $permalink = $new_permalink;
            $addr{$permalink} = 1;
            last;
          }
          $num++;
        }
      } else
      {
        $addr{$permalink} = 1;
      }
      $permalink =~ s"(?<!http:)/+"/"g;

      @permalink = split (/\//, $permalink);
      $self->{$utid}->{_spec}->{address} = catfile(@permalink, "index.html");
      $self->{$utid}->{url} = $permalink;
        #$self->{$utid}->{url} =
        #"$baseurl/".
        #"$floor/".
        #"$self->{$utid}->{url}";
      $self->{$utid}->{url} =~ s"(?<!http:)/+"/"g;
  } #end foreach utid;


}


#list maker
sub lists {
  my $self = shift;
  my $_fields = shift;
  my $config = shift;

  my $list = {};
  my @month_names = qw(January February March April May June July August September October November December);
  my @jmonth_names = qw(فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند);

  foreach my $utid (keys %$self)
  {
    my $floor = $self->{$utid}->{floor};

    if (defined $self->{$utid}->{date})
    {
      my $date_field = $self->{$utid}->{date};
      if ($date_field =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
      {
        my $year = $self->{$utid}->{_spec}->{year};
        my $month = $self->{$utid}->{_spec}->{month};
        push @{ $list->{$floor}->{date}->{"$year$month"}->{posts} }, $utid;

        $list->{$floor}->{date}->{"$year$month"}->{name} = "$month_names[$month-1] $year";
        $list->{$floor}->{date}->{"$year$month"}->{_year} = $year;
        $list->{$floor}->{date}->{"$year$month"}->{_month} = $month;
        $list->{$floor}->{date}->{"$year$month"}->{number} = "$year - $month";
        $list->{$floor}->{date}->{"$year$month"}->{_number} = "$year$month";
        $list->{$floor}->{date}->{"$year$month"}->{url} =
        "$config->{$floor}->{root}/archive/".
        "$year/$month";
        $list->{$floor}->{date}->{"$year$month"}->{url} =~ s{(?<!http:)/+}{/}g;
#        .$self->{$utid}->{$field}->{$list_items[$i]}->{url};
      }
    }

    if (defined $self->{$utid}->{jdate})
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
        $list->{$floor}->{jdate}->{"$year$month"}->{_month} = $month;
        $list->{$floor}->{jdate}->{"$year$month"}->{number} = "$year - $month";
        $list->{$floor}->{jdate}->{"$year$month"}->{_number} = "$year$month";
        $list->{$floor}->{jdate}->{"$year$month"}->{url} =
        "$config->{$floor}->{root}/archive/".
        "$year/$month";
        $list->{$floor}->{jdate}->{"$year$month"}->{url} =~ s{(?<!http:)/+}{/}g;
      }
    }

    foreach my $field (keys %{$self->{$utid}})
    {
      my $_field_test;
      if (exists $_fields->{$floor}->{$field})
      {
        $_field_test = 'list'; #$_fields->{$floor}->{$field};
#      } elsif (exists $_fields->{default}->{$field})
#      {
#        $_field_test = $_fields->{default}->{$field};
      } else
      {
        $_field_test = 'single';
      }

      my @list_items;
      my @list_items_url;

      if ($_field_test =~ /(list|global)/)
      {
        if ($self->{$utid}->{$field} and ref($self->{$utid}->{$field}) eq "ARRAY")
        {
          @list_items = @{ $self->{$utid}->{$field} };
        } elsif ($self->{$utid}->{$field})
        {
          my $_items = $self->{$utid}->{$field};
          push @list_items, $_items;
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
          #$self->{$utid}->{$field}->{$list_items[$i]}->{url} = $list_items_url[$i];
          if ($config->{$floor}->{namespace}->{$list_items[$i]})
          {
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} = $config->{$floor}->{namespace}->{$list_items[$i]};
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =~ s:[^\w]:-:g;
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =
            "$config->{$floor}->{root}/".
            "$field/".
            $self->{$utid}->{$field}->{$list_items[$i]}->{url};
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =~ s{(?<!http:)/+}{/}g;
            $list->{$floor}->{$field}->{$list_items[$i]}->{url} = $self->{$utid}->{$field}->{$list_items[$i]}->{url};
          } else {
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =
            "$config->{$floor}->{root}/".
            "$field/".
            $list_items_url[$i];
            $self->{$utid}->{$field}->{$list_items[$i]}->{url} =~ s{(?<!http:)/+}{/}g;
            $list->{$floor}->{$field}->{$list_items[$i]}->{url} = $self->{$utid}->{$field}->{$list_items[$i]}->{url};
          }
        }
      }
    }

  }

  return $list;
}







sub floors {
  my $self = shift;
  my $floor = {};

	foreach my $utid (keys %$self)
  {
		foreach my $value (keys %{$self->{$utid}})
    {
			if ($value eq "floor")
      {
				push @{ $floor->{$self->{$utid}->{$value}} }, $utid;
			}
		}
	}
  return $floor;
}



sub date {
  my $self = shift;
  my $date = {};
  foreach my $utid (keys %$self)
  {
    if (defined $self->{$utid}->{date})
    {
      my $date_field = $self->{$utid}->{date};
      if ($date_field =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
      {
        #my $year = sprintf "%04d", $+{year};
        #my $month = sprintf "%02d", $+{month};
        my $year = $self->{$utid}->{_spec}->{year};
        my $month = $self->{$utid}->{_spec}->{month};
        #push @{ $date->{'y-m'}->{"$year-$month"} }, $utid;
        #push @{ $date->{y}->{$year}->{$month} }, $utid;
        my $floor = $self->{$utid}->{floor};
        push @{ $date->{$floor}->{$year}->{$month}->{posts} }, $utid;
        $date->{$floor}->{$year}->{$month}->{name} = "$month";
#        $date->{$floor}->{$year}->{$month}->{url} =
#        "$config->{$floor}->{root}/".
#        "$field/".
#        $self->{$utid}->{$field}->{$list_items[$i]}->{url};
      }
    }
#    if (defined $self->{$utid}->{jdate})
#    {
#      my $date_field = $self->{$utid}->{jdate};
#      if ($date_field =~ /^(?<year>\d{2,4})-(?<month>\d{1,2})-(?<day>\d{1,2})/)
#      {
#        my $jyear = $self->{$utid}->{_spec}->{jyear};
#        my $jmonth = $self->{$utid}->{_spec}->{jmonth};
#        my $floor = $self->{$utid}->{floor};
#        push @{ $date->{$floor}->{$jyear}->{$jmonth}->{posts} }, $utid;
#        $date->{$floor}->{$jyear}->{$jmonth}->{name} = "$jmonth";
#      }
#    }
  }

  return $date;

}


1;
