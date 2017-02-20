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
  my $floors = $switches{floors};
  my $config = $switches{config}; #configs
  my $pensource = $switches{pensource};
  my $floor_data = $switches{floor_data};

  my $template_root = catdir($pensource,'template', $config->{_default}->{template});

  my $root_index = Template->new({
      INCLUDE_PATH => [$template_root, catdir($template_root, 'include') ],
      INTERPOLATE  => 1,
      ENCODING => 'utf8',
      START_TAG => quotemeta('{{'),
      END_TAG   => quotemeta('}}'),
  }) || die "$Template::ERROR\n";

  my $vars = {
  	 TITLE => $config->{_default}->{title},
     DESCRIPTION => $config->{_default}->{description},
     URL => $config->{_default}->{url},
     ROOT => $config->{_default}->{root},
     STATIC => $config->{_default}->{static},
     IMGURL => $config->{_default}->{imageurl},
     AUTHOR => $config->{_default}->{author},
     EMAIL => $config->{_default}->{email},
     PageTITLE => $config->{_default}->{title},
     Entries  => $allentries,
     Floors => $floor_data,
     UTIDS => $allposts,
     CONF => $config->{_default},
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
   $vars->{ROOT} = "/" . $vars->{ROOT} if $vars->{ROOT} !~ m:^/:;
   $vars->{ROOT} =~ s"/+"/"g;
   $vars->{ROOT} =~ s"/$""g unless $vars->{ROOT} eq "/";


  my $index = catfile($pensource, 'public', $config->{_default}->{root}, 'index.html');
  $root_index->process('main.tt2', $vars, $index, { binmode => ':utf8' })
      || die $root_index->error(), "\n";

return 1;
}

1;
