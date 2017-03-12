package Mira::Control::Content::Address;
$Mira::Control::Content::Address::VERSION = '00.07.22';

use strict;
use warnings;
use 5.012;

use File::Spec;
use File::Spec::Functions;
use File::Basename;

sub address {
  my $class = shift;
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
        $permanent = ":year/:month/:day/:title/";
      }
#      $permanent .= "/:title" if $permanent !~ /:title/;


  ####### make Address Field #######
      my $permalink = $self->{$utid}->{_permalink} ? $self->{$utid}->{_permalink} : $permanent;
      $permalink .= "/:title" if $permalink !~ /:title/;
      $permalink =~ s:^/+::;

      $permalink =~ s/:year/$self->{$utid}->{_spec}->{year}/g if (defined $self->{$utid}->{_spec}->{year});
      $permalink =~ s/:month/$self->{$utid}->{_spec}->{month}/g if (defined $self->{$utid}->{_spec}->{month});
      $permalink =~ s/:day/$self->{$utid}->{_spec}->{day}/g if (defined $self->{$utid}->{_spec}->{day});
      $permalink =~ s/(:year|:month|:day)//g;

      while ($permalink =~ m{:(.*?)(/|$)}g)
      {
        next if $1 eq 'title';
        my $field = $1;
        if ($self->{$utid}->{$field} and not ref($self->{$utid}->{$field}))
        {
          $permalink =~ s/:$field/$self->{$utid}->{$field}/g;
        } else
        {
          $permalink =~ s/:$field//g;
        }
      }

      my @permalink = split (m:/:, $permalink);
      @permalink = map {$_ =~ s/\W//g if $_ !~ m/:title/; $_} @permalink;
      $permalink = join ("/", $baseurl, @permalink, "");
      $permalink =~ s{(?<!:)/+}{/}g;
      #$permalink =~ s"(?<!http:)/+"/"g;

      my $titr_address = $self->{$utid}->{_index} ? $self->{$utid}->{_index} : $self->{$utid}->{title};
      $titr_address =~ s/[^\w]+$//g;
      $titr_address = $utid if (! $titr_address);
      $titr_address =~ s/[^\w]+/-/g;
      $self->{$utid}->{slug} = $titr_address;
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
      #$permalink = $permalink . "/";
      $permalink =~ s{(?<!:)/+}{/}g;
      #$permalink =~ s"(?<!http:)/+"/"g;

      @permalink = split (/\//, $permalink);
      my $ext = $config->{$floor}->{output_extension} || 'html';
      $ext =~ s{^\.+}{};
      $self->{$utid}->{_spec}->{address} = catfile(@permalink, "index.$ext");
      $self->{$utid}->{url} = $permalink;
      $self->{$utid}->{url} =~ s{(?<!:)/+}{/}g;
      #$self->{$utid}->{url} =~ s"(?<!http:)/+"/"g;
    } #end foreach utid;


}


1;
