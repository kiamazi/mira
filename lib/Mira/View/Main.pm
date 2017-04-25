package Mira::View::Main;
$Mira::View::Main::VERSION = '00.07.38';

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
#  my $floors = $switches{floors};
  my $config = $switches{config}; #configs
  my $pensource = $switches{pensource};
  my $floor_data = $switches{floor_data};
  my $build = $switches{build};

  my $template_root;

  if (defined $config->{_default}->{template} and -f catfile($pensource,'template', $config->{_default}->{template}, 'main.tt2') )
  {
    $template_root = catdir($pensource,'template', $config->{_default}->{template});
  } else
  {
    return;
  }

  my $root_index = Template->new({
      INCLUDE_PATH => [$template_root, catdir($template_root, 'include') ],
      INTERPOLATE  => 1,
      ENCODING => 'utf8',
      START_TAG => quotemeta('{{'),
      END_TAG   => quotemeta('}}'),
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
     PageTITLE => $config->{_default}->{title},
     ENTRIES  => $allentries,
     FLOORS => $floor_data,
     UTIDS => $allposts,
     MAIN => $config->{_default},
     BUILD => $build,
     IS_MAIN => 'true',
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

   $vars->{MainROOT} =~ s{^(.*?):/+}{/};
   $vars->{MainROOT} = "/" . $vars->{MainROOT} if $vars->{MainROOT} !~ m:^/:;
   $vars->{MainROOT} =~ s{/+}{/}g;
   $vars->{MainROOT} =~ s{/$}{}g unless $vars->{MainROOT} eq "/";

  my $ext = $config->{_default}->{output_extension} || 'html';
  $ext =~ s{^\.+}{};
  my $index = catfile($pensource, $config->{_default}->{publishDIR}, $config->{_default}->{root}, "index.$ext");
  $root_index->process('main.tt2', $vars, $index, { binmode => ':utf8' })
      || die $root_index->error(), "\n";

return 1;
}

1;
