package Mira::View::Feed;
$Mira::View::Feed::VERSION = '00.07.29';

use strict;
use warnings;
use utf8;
use 5.012;

use File::Spec;
use File::Spec::Functions;
use Template;


sub template {
  my $class = shift;
  my %switches = @_;

  my $allposts = $switches{posts}; #all utids reverse sorted
  my $allentries = $switches{allentries}; #all entries data hash
  my $floors = $switches{floors};
  my $config = $switches{config}; #configs
  my $pensource = $switches{pensource};
  my $archives = $switches{archives};
  my $floor_data = $switches{floor_data};
  my $build = $switches{build};


  foreach my $floor (keys %$floors)
  {
    my $floor_template_root =
      (-f catfile($pensource,'template',$config->{$floor}->{template},'index.tt2') )
      ? catdir($pensource,'template',$config->{$floor}->{template})
      : catdir($pensource,'template', $config->{_default}->{template});


    my @utids = @{$floors->{$floor}};
    @utids = reverse sort @utids;
    @utids = grep {
      not $allentries->{$_}->{_type} or $allentries->{$_}->{_type} !~ m/^(page|draft)$/
    } @utids;
    my $num = $config->{$floor}->{feed_post_num} ? $config->{$floor}->{feed_post_num} : $config->{_default}->{feed_post_num};
    @utids = splice @utids, 0, $num;



        my $floor_index = Template->new({
            INCLUDE_PATH => [ $floor_template_root, catdir($floor_template_root, 'include') ],
            INTERPOLATE  => 1,
            ENCODING => 'utf8',
            START_TAG => quotemeta('{{'),
            END_TAG   => quotemeta('}}'),
            OUTLINE_TAG => '{%',
          }) || die "$Template::ERROR\n";

        my $vars = {
          MainTITLE       => $config->{_default}->{title},
          MainDESCRIPTION => $config->{_default}->{description},
          MainURL         => $config->{_default}->{url},
          MainROOT        => $config->{_default}->{root},
          MainSTATIC      => $config->{_default}->{static},
       	  MainIMAGEURL    => $config->{_default}->{imageurl},
          MainAUTHOR      => $config->{_default}->{author},
          MainEMAIL       => $config->{_default}->{email},
          TITLE           => $config->{$floor}->{title},
          DESCRIPTION     => $config->{$floor}->{description},
          URL             => $config->{$floor}->{url},
          ROOT            => $config->{$floor}->{root},
          STATIC          => $config->{$floor}->{static},
          IMAGEURL        => $config->{$floor}->{imageurl},
          AUTHOR          => $config->{$floor}->{author},
          EMAIL           => $config->{$floor}->{email},

          PageTITLE       => $config->{$floor}->{title},

          ENTRIES         => $allentries,
          FLOORS          => $floor_data,
          ARCHIVES        => {%{$archives->{$floor}->{list}}, %{$archives->{$floor}->{date}}}, #$archives->{$floor}->{list},

          MAIN            => $config->{_default},
          SITE            => $config->{$floor},
          BUILD           => $build,

          FarsiNum        => bless(\&farsinum, 'mira'),
        }; #sort { <=> }

        sub farsinum {
          my $string = shift;
          $string =~ tr/1234567890/۱۲۳۴۵۶۷۸۹۰/;
          return $string;
        }

        #$vars->{MainURL} =~ s"(?<!http:)/+"/"g;
        $vars->{MainURL} =~ s{(?<!:)/+}{/}g;
        $vars->{MainURL} =~ s{/$}{}g;

        $vars->{MainROOT} =~ s{^(.*?):/+}{/};
        $vars->{MainROOT} = "/" . $vars->{MainROOT} if $vars->{MainROOT} !~ m:^/:;
        $vars->{MainROOT} =~ s{/+}{/}g;
        $vars->{MainROOT} =~ s{/$}{}g unless $vars->{MainROOT} eq "/";

        #$vars->{URL} =~ s"(?<!http:)/+"/"g;
        $vars->{URL} =~ s{(?<!:)/+}{/}g;
        $vars->{URL} =~ s{/$}{}g;

        $vars->{ROOT} =~ s{^(.*?):/+}{/};
        $vars->{ROOT} = "/" . $vars->{ROOT} if $vars->{ROOT} !~ m:^/:;
        $vars->{ROOT} =~ s{/+}{/}g;
        $vars->{ROOT} =~ s{/$}{}g unless $vars->{ROOT} eq "/";

        foreach my $field (keys %{$archives->{$floor}->{list}})
        {
          $vars->{uc($field)."_ARCHIVE"} = [
          reverse sort
          {
            $#{$a->{posts}} <=> $#{$b->{posts}}
            or
            $a->{name} cmp $b->{name}
          }
          (values %{ $archives->{$floor}->{list}->{$field} })
          ];
        }

        foreach my $field (keys %{$archives->{$floor}->{date}})
        {
          $vars->{uc($field)."_ARCHIVE"} = [
          reverse sort
          {
            $a->{_year} <=> $b->{_year}
            or
            $a->{_number} <=> $b->{_number}
          }
          (values %{ $archives->{$floor}->{date} })
          ];
        }

        my $posts = [];
        foreach my $utid (@utids)
        {
          push @$posts, $allentries->{$utid};
        }
        $vars->{POSTS} = $posts;
        my $feedindex = catfile($pensource, 'public', $config->{$floor}->{root}, 'feed.xml');
        $floor_index->process('atom.tt2', $vars, $feedindex, { binmode => ':utf8' })
            || die $floor_index->error(), "\n";


  }


}

1;
