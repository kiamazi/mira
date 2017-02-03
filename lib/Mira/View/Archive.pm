package Mira::View::Archive;

use strict;
use warnings;
use utf8;
use 5.012;

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
  my $lists = $switches{lists};
  my $floor_data = $switches{floor_data};

#  my $floor_data = {};
#  foreach my $floor (keys %$floors)
#  {
#    my @entries = reverse sort @{$floors->{$floor}};
#    splice @entries, $config->{_default}->{post_num} if ($config->{_default}->{post_num} ne 'all');
#    $floor_data->{$floor}->{name} = $config->{$floor}->{title};
#    $floor_data->{$floor}->{description} = $config->{$floor}->{description};
#    $floor_data->{$floor}->{url} = $config->{$floor}->{root};
#    foreach my $utid (@entries)
#    {
#      push @{ $floor_data->{$floor}->{posts} }, $allentries->{$utid};
#    }
#  }

  foreach my $floor (keys %$lists) {

  	foreach my $archive ( keys %{ $lists->{$floor} } ) {
  		my $archive_template_root =
      (
      -f catfile($pensource,'template',$config->{$floor}->{template},'archive.tt2')
      or
      -f catfile($pensource,'template',$config->{$floor}->{template},"$archive.tt2")
      )
  		? catdir($pensource,'template',$config->{$floor}->{template})
      : catdir($pensource,'template', $config->{_default}->{template});

  		foreach my $list ( keys %{ $lists->{$floor}->{$archive} } ) {
  			my $show_list_url = $lists->{$floor}->{$archive}->{$list}->{url};
        my @show_list_address = split (m:/:, $show_list_url);
  			my @utids = @{$lists->{$floor}->{$archive}->{$list}->{posts}};
  			@utids = reverse sort @utids;

  			my $archive_index = Template->new({
  		    	INCLUDE_PATH => [ $archive_template_root, catdir($archive_template_root, 'include') ],
  		    	INTERPOLATE  => 1,
            ENCODING => 'utf8',
  				}) || die "$Template::ERROR\n";

        my $vars = {
          TITLE => $config->{_default}->{title},
          DESCRIPTION => $config->{_default}->{description},
          URL => $config->{_default}->{url},
          ROOT => $config->{_default}->{root},
          STATIC => $config->{_default}->{static},
       	  IMGURL => $config->{_default}->{imgurl},
          AUTHOR => $config->{_default}->{author},
          EMAIL => $config->{_default}->{email},
          FloorTITLE => $config->{$floor}->{title},
          FloorDESCRIPTION => $config->{$floor}->{description},
          FloorURL => $config->{$floor}->{url},
          FloorROOT => $config->{$floor}->{root},
          FloorSTATIC => $config->{$floor}->{static},
          FloorIMGURL => $config->{$floor}->{imgurl},
          FloorAUTHOR => $config->{$floor}->{author},
          FloorEMAIL => $config->{$floor}->{email},
          ArchiveTITLE => $list,
          PageTITLE => "$config->{$floor}->{title} - $list",
          Entries  => $allentries,
          Floors => $floor_data,
          Archives => $lists->{$floor},
          FarsiNum => bless(\&farsinum, 'mira'),
        };

        sub farsinum {
          my $string = shift;
          $string =~ tr/1234567890/۱۲۳۴۵۶۷۸۹۰/;
          return $string;
        }

        $vars->{URL} =~ s"(?<!http:)/+"/"g;
        $vars->{URL} =~ s"/$""g;

        $vars->{ROOT} =~ s"^http:/+"/"g;
        $vars->{ROOT} = "/" . $vars->{ROOT};
        $vars->{ROOT} =~ s"/+"/"g;
        $vars->{ROOT} =~ s"/$""g;

        $vars->{FloorURL} =~ s"(?<!http:)/+"/"g;
        $vars->{FloorURL} =~ s"/$""g;

        $vars->{FloorROOT} =~ s"^http:/+"/"g;
        $vars->{FloorROOT} = "/" . $vars->{FloorROOT};
        $vars->{FloorROOT} =~ s"/+"/"g;
        $vars->{FloorROOT} =~ s"/$""g;

        foreach my $archive (keys %{$lists->{$floor}})
        {
          next if $archive eq 'date';
          next if $archive eq 'jdate';
          #$vars->{$archive} = [ values %{ $lists->{$floor}->{$archive} } ]; #TRUE VALUE
          $vars->{$archive} = [
          reverse sort
          {
            $#{$a->{posts}} <=> $#{$b->{posts}}
            or
            $a->{name} cmp $b->{name}
          }
          (values %{ $lists->{$floor}->{$archive} })
          ];
        }

        if ($lists->{$floor}->{date})
        {
          $vars->{Date} = [
          reverse sort
          {
            $a->{_number} <=> $b->{_number}
          }
          (values %{ $lists->{$floor}->{date} })
          ];
        }

        if ($lists->{$floor}->{jdate})
        {
          $vars->{JDate} = [
          reverse sort
          {
            $a->{_year} <=> $b->{_year}
            or
            $a->{_number} <=> $b->{_number}
          }
          (values %{ $lists->{$floor}->{jdate} })
          ];
        }

        my $archive_post_num = ($config->{$floor}->{archive_post_num} eq 'all') ? scalar @utids : $config->{$floor}->{archive_post_num};
        my $page = 1;
        while (my @pagepost = splice @utids, 0, $archive_post_num)
        {
          my $posts = [];
          foreach my $utid (@pagepost)
          {
            push @$posts, $allentries->{$utid};
          }
          $vars->{POSTS} = $posts;


          my $target = $page == 1 ? "index.html" : "/page/$page/index.html";
          my $index = catfile($pensource, 'public', @show_list_address, $target);

          $vars->{next} = @utids ? "$show_list_url/page/" . ($page+1) . "/index.html" : '' ;
          $vars->{next} =~ s"(?<!http:)/+"/"g if $vars->{next};
          $vars->{prev} = $page == 1 ? '' : "$show_list_url/page/" . ($page-1) . "/index.html" ;
          $vars->{prev} = "$show_list_url/index.html" if $page == 2;
          $vars->{prev} =~ s"(?<!http:)/+"/"g if $vars->{prev};

          my $arch_template = (-f catfile($archive_template_root, "$archive.tt2"))
           ?
           "$archive.tt2" : "archive.tt2";
#$opts{source}/public/$show_list_url/index.html
          $archive_index->process($arch_template, $vars, $index, { binmode => ':utf8' })
              || die $archive_index->error(), "\n";
          $page++;
        }
  		}
  	}
  }

}

1;
