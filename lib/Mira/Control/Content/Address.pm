package Mira::Control::Content::Address;
$Mira::Control::Content::Address::VERSION = '00.07.56';

use strict;
use warnings;
use 5.012;

use File::Spec;
use File::Spec::Functions;
use File::Basename;

sub address {
    my $class  = shift;
    my $self   = shift;
    my $config = shift;

    my %addr;

    my @utid = keys %$self;
    @utid = sort @utid;
    foreach my $utid (@utid)
    {
        my $floor = $self->{$utid}->{floor};

        my $baseurl;
        $baseurl = $config->{$floor}->{root};

        my $permanent;
        if ( $config->{$floor} and $config->{$floor}->{permalink} ) {
            $permanent = $config->{$floor}->{permalink};
        } else {
            $permanent = ":year/:month/:day/:title/";
        }

        ####### make Address Field #######
        my $permalink =
            $self->{$utid}->{_permalink}
          ? $self->{$utid}->{_permalink}
          : $permanent;
        $permalink .= "/:title" if $permalink !~ /:title/;
        $permalink =~ s:^/+::;

        $permalink =~ s/:year/$self->{$utid}->{CALENDAR}->{year}/g
          if ( defined $self->{$utid}->{CALENDAR}->{year} );
        $permalink =~ s/:month/$self->{$utid}->{CALENDAR}->{month}/g
          if ( defined $self->{$utid}->{CALENDAR}->{month} );
        $permalink =~ s/:day/$self->{$utid}->{CALENDAR}->{day}/g
          if ( defined $self->{$utid}->{CALENDAR}->{day} );
        $permalink =~ s/(:year|:month|:day)//g;

        while ( $permalink =~ m{:(.*?)(/|$)}g ) {
            next if $1 =~ /title/;
            my $field = $1;
            if ( $self->{$utid}->{$field}
                and not ref( $self->{$utid}->{$field} ) )
            {
                $permalink =~ s/:$field/$self->{$utid}->{$field}/g;
            } else {
                $permalink =~ s/:$field//g;
            }
        }

        my @permalink = split( m{/}, $permalink );
        @permalink =
          map { $_ =~ s/[^\w\.-]//g if $_ !~ m/:title/; $_ } @permalink;
        $permalink = join( "/", $baseurl, @permalink );    #, "");
        $permalink =~ s{(?<!:)/+}{/}g;  #can't remember why? :/

        my $titr_address =
            $self->{$utid}->{_index}
          ? $self->{$utid}->{_index}
          : $self->{$utid}->{title};
        $titr_address =~ s/[^\w]+$//g;
        $titr_address =~ s/[^\w]+/-/g;
        $self->{$utid}->{slug} = $titr_address;
        my $url;
        my $address;
        $permalink =~ s/:title/$titr_address/g;

        if ( defined $addr{$permalink} ) {
            my $num = 2;
            while (1) {
                my $new_permalink = $permalink;
                if ( $permalink =~ m{.*/.*?\.[^/]*?$} ) {
                    $new_permalink =~ s{(.*)/(.*?)$}{$1/$num/$2};
                } else {
                    $new_permalink = "$permalink/$num";
                }
                unless ( exists $addr{$new_permalink} ) {
                    $permalink = $new_permalink;
                    $addr{$permalink} = 1;
                    last;
                }
                $num++;
            }
        } else {
            $addr{$permalink} = 1;
        }

        $permalink =~ s{(?<!:)/+}{/}g;  #can't remember why? :/
        $permalink = lc($permalink);

        if ( $permalink !~ m{.*/.*?\.[^/]*?$} ) {
            $permalink = $permalink . "/";
            @permalink = split( m{/}, $permalink );
            my $ext = $config->{$floor}->{output_extension} || 'html';
            $ext =~ s{^\.+}{};
            $self->{$utid}->{SPEC}->{address} =
              catfile( @permalink, "index.$ext" );
        } else {
            @permalink = split( m{/}, $permalink );
            $self->{$utid}->{SPEC}->{address} =
              catfile(@permalink);    #, "index.$ext");
        }

        $self->{$utid}->{url} = $permalink;
        $self->{$utid}->{url} =~ s{(?<!:)/+}{/}g;  #can't remember why? :/

        $self->{$utid}->{furl} = $self->{$utid}->{url};
        my $furl = qr{^$baseurl};
        my $fpath = $config->{$floor}->{url};
        $self->{$utid}->{furl} =~ s/$furl/$fpath/ if $config->{$floor}->{root};

    }    #end foreach utid;

}

1;
