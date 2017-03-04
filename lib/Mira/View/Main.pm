package Mira::View::Main;
$Mira::View::Main::VERSION = '0.07';

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

  my $template_root = catdir($pensource,'template', $config->{_default}->{template});

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
     Entries  => $allentries,
     Floors => $floor_data,
     UTIDS => $allposts,
     MAIN => $config->{_default},
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


  my $index = catfile($pensource, 'public', $config->{_default}->{root}, 'index.html');
  $root_index->process('main.tt2', $vars, $index, { binmode => ':utf8' })
      || die $root_index->error(), "\n";

return 1;
}

1;
