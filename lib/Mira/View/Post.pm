package Mira::View::Post;
$Mira::View::Post::VERSION = '00.07.31';

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
    my @utids = @{$floors->{$floor}};
    @utids = ($config->{$floor}->{post_sort} and $config->{$floor}->{post_sort} eq 'reverse') ? sort @utids : reverse sort @utids;
    my $max_post = $#utids; #number of posts in this floor
    my $pn = 0; #post_number > loop number
    foreach my $utid (@utids)
    {
  	   #my $floor = $allentries->{$utid}->{floor};
       my $page = {};

      unless ($allentries->{$utids[$pn]}->{_type} and $allentries->{$utids[$pn]}->{_type} eq "page")
      {
       for (my $var = $pn+1; $var <= $max_post; $var++) {
         if ($allentries->{$utids[$var]}->{_type} and $allentries->{$utids[$var]}->{_type} eq "page")
         {
           next;
         } else
         {
           $page->{next}->{url} = $allentries->{$utids[$var]}->{url};
           $page->{next}->{title} = $allentries->{$utids[$var]}->{title};
           last;
         }
       }

       for (my $var = $pn-1; $var >= 0; $var--) {
         if ($allentries->{$utids[$var]}->{_type} and $allentries->{$utids[$var]}->{_type} eq "page")
         {
           next;
         } else
         {
           $page->{prev}->{url} = $allentries->{$utids[$var]}->{url};
           $page->{prev}->{title} = $allentries->{$utids[$var]}->{title};
           last;
         }
       }
      }
       $pn++;


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
         next;
         #$post_template_root = catdir($pensource,'template', $config->{_default}->{template});
         #$post_layout = 'post.tt2';
       }
#    my $post_template_root =
#      (-f catfile($pensource,'template',$config->{$floor}->{template},'post.tt2') )
#      ? catdir($pensource,'template',$config->{$floor}->{template})
#      : catdir($pensource,'template', $config->{_default}->{template});


  	   my $post_index = Template->new({
  		   INCLUDE_PATH => [ $post_template_root, catdir($post_template_root, 'include') ],
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

         PageTITLE       => "$allentries->{$utid}->{title} - $config->{$floor}->{title}",
         PostTITLE       => $allentries->{$utid}->{title},

         ENTRIES         => $allentries,
         FLOORS          => $floor_data,
         ARCHIVES        => {%{$archives->{$floor}->{list}}, %{$archives->{$floor}->{date}}}, #$archives->{$floor}->{list},

         MAIN            => $config->{_default},
         SITE            => $config->{$floor},
         BUILD           => $build,
         FarsiNum        => bless(\&farsinum, 'mira'),

         PAGE            => $page,

         FarsiNum => bless(\&farsinum, 'mira'),
  	   };

       sub farsinum {
         my $string = shift;
         $string =~ tr/1234567890/۱۲۳۴۵۶۷۸۹۰/;
         return $string;
       }

       #$vars->{MainURL} =~ s"(?<!http:)/+"/"g;
       $vars->{MainURL} =~ s{(?<!:)/+}{/}g;
       $vars->{MainURL} =~ s{/$}{}g;

       $vars->{MainROOT} =~ s{^(.*?):/+}{/}g;
       $vars->{MainROOT} = "/" . $vars->{MainROOT} if $vars->{MainROOT} !~ m:^/:;
       $vars->{MainROOT} =~ s{/+}{/}g;
       $vars->{MainROOT} =~ s{/$}{}g unless $vars->{MainROOT} eq "/";

       #$vars->{URL} =~ s"(?<!http:)/+"/"g;
       $vars->{URL} =~ s{(?<!:)/+}{/}g;
       $vars->{URL} =~ s{/$}{}g;

       $vars->{ROOT} =~ s{^(.*?):/+}{/}g;
       $vars->{ROOT} = "/" . $vars->{ROOT} if $vars->{ROOT} !~ m:^/:;
       $vars->{ROOT} =~ s{/+}{/}g;
       $vars->{ROOT} =~ s{/$}{}g unless $vars->{ROOT} eq "/";

       my $posts = [];
       push @$posts, $allentries->{$utid};
       #@$posts = %{$allentries->{$utid}};
       $vars->{POSTS} = $posts;
       $vars->{post} = $allentries->{$utid};

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
         (values %{ $archives->{$floor}->{date}->{$field} })
         ];
       }

       #my @target = split (m:/:, $allentries->{$utid}->{_spec}->{address});
       my $index = catfile($pensource, 'public', $allentries->{$utid}->{_spec}->{address});

  	   $post_index->process($post_layout, $vars, $index, { binmode => ':utf8' })
  		   || die $post_index->error(), "\n";

    }
  }

}

1;
