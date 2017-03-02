package Mira::View::Post;
$Mira::View::Post::VERSION = '0.07';

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
  my $lists = $switches{lists};
  my $floor_data = $switches{floor_data};
  my $build = $switches{build};


  foreach my $utid (keys %$allentries)
  {
  	my $floor = $allentries->{$utid}->{floor};

    my $post_template_root;
    my $post_layout;
    if (
    $allentries->{$utid}->{_layout}
    and
    -f catfile($pensource,'template',$config->{$floor}->{template},$allentries->{$utid}->{_layout})
    ) {
      $post_template_root = catdir($pensource,'template',$config->{$floor}->{template});
      $post_layout = $allentries->{$utid}->{_layout};
    } elsif (-f catfile($pensource,'template',$config->{$floor}->{template},'post.tt2') )
    {
      $post_template_root = catdir($pensource,'template',$config->{$floor}->{template});
      $post_layout = 'post.tt2';
    } else
    {
      $post_template_root = catdir($pensource,'template', $config->{_default}->{template});
      $post_layout = 'post.tt2';
    }
#    my $post_template_root =
#      (-f catfile($pensource,'template',$config->{$floor}->{template},'post.tt2') )
#      ? catdir($pensource,'template',$config->{$floor}->{template})
#      : catdir($pensource,'template', $config->{_default}->{template});


  	#TODO complete and check this code, for each post template


  	my $post_index = Template->new({
  			INCLUDE_PATH => [ $post_template_root, catdir($post_template_root, 'include') ],
  			INTERPOLATE  => 1,
        ENCODING => 'utf8',
        START_TAG => quotemeta('{{'),
        END_TAG   => quotemeta('}}'),
        OUTLINE_TAG => '{%',
  		}) || die "$Template::ERROR\n";

    my $vars = {
      MainTITLE => $config->{_default}->{title},
      MainDESCRIPTION => $config->{_default}->{description},
      MainURL => $config->{_default}->{url},
      MainROOT => $config->{_default}->{root},
      MainSTATIC => $config->{_default}->{static},
      MainIMAGEURL => $config->{_default}->{imageurl},
      MainAUTHOR => $config->{_default}->{author},
      MainEMAIL => $config->{_default}->{email},
      TITLE => $config->{$floor}->{title},
      DESCRIPTION => $config->{$floor}->{description},
      URL => $config->{$floor}->{url},
      ROOT => $config->{$floor}->{root},
      STATIC => $config->{$floor}->{static},
      IMAGEURL => $config->{$floor}->{imageurl},
      AUTHOR => $config->{$floor}->{author},
      EMAIL => $config->{$floor}->{email},
      PageTITLE => "$allentries->{$utid}->{title} - $config->{$floor}->{title}",
      PostTITLE => $allentries->{$utid}->{title},
      Entries  => $allentries,
      Floors => $floor_data,
      Archives => $lists->{$floor},
      MAIN => $config->{_default},
      SITE => $config->{$floor},
      BUILD => $build,
      FarsiNum => bless(\&farsinum, 'mira'),
    };

    sub farsinum {
      my $string = shift;
      $string =~ tr/1234567890/۱۲۳۴۵۶۷۸۹۰/;
      return $string;
    }

    $vars->{MainURL} =~ s"(?<!http:)/+"/"g;
    $vars->{MainURL} =~ s"/$""g;

    $vars->{MainROOT} =~ s"^http:/+"/"g;
    $vars->{MainROOT} = "/" . $vars->{MainROOT} if $vars->{MainROOT} !~ m:^/:;
    $vars->{MainROOT} =~ s"/+"/"g;
    $vars->{MainROOT} =~ s"/$""g unless $vars->{MainROOT} eq "/";

    $vars->{URL} =~ s"(?<!http:)/+"/"g;
    $vars->{URL} =~ s"/$""g;

    $vars->{ROOT} =~ s"^http:/+"/"g;
    $vars->{ROOT} = "/" . $vars->{ROOT} if $vars->{ROOT} !~ m:^/:;
    $vars->{ROOT} =~ s"/+"/"g;
    $vars->{ROOT} =~ s"/$""g unless $vars->{ROOT} eq "/";

    my $posts = [];
    push @$posts, $allentries->{$utid};
    #@$posts = %{$allentries->{$utid}};
    $vars->{POSTS} = $posts;



    foreach my $archive (keys %{$lists->{$floor}})
    {
      next if $archive eq 'date';
      next if $archive eq 'jdate';
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
        $a->{_year} <=> $b->{_year}
        or
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

    my @target = split (m:/:, $allentries->{$utid}->{_spec}->{address});
    my $index = catfile($pensource, 'public', @target);

  	$post_index->process($post_layout, $vars, $index, { binmode => ':utf8' })
  			|| die $post_index->error(), "\n";

  }

}

1;
