package Mira::View::Main;

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
  my $floor_data = $switches{floor_data};

#  my $data = $switches->{data};
  my $template_root = catdir($pensource,'template', $config->{_default}->{template});

#  my $floor_data = {};
#  foreach my $floor (keys %$floors)
#  {
#  	my @entries = reverse sort @{$floors->{$floor}};
#  	splice @entries, $config->{_default}->{post_num} if ($config->{_default}->{post_num} ne 'all');
#    $floor_data->{$floor}->{name} = $config->{$floor}->{title};
#    $floor_data->{$floor}->{description} = $config->{$floor}->{description};
#    $floor_data->{$floor}->{url} = $config->{$floor}->{root};
#  	foreach my $utid (@entries)
#  	{
#  		push @{ $floor_data->{$floor}->{Posts} }, $allentries->{$utid};
#  	}
#  }
#use Data::Dumper;
#print Dumper($floor_data);
#exit;

  my $root_index = Template->new({
      INCLUDE_PATH => [$template_root, catdir($template_root, 'include') ],
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
     PageTITLE => $config->{_default}->{title},
     Entries  => $allentries,
     Floors => $floor_data,
     Posts => $allposts,
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

  my $index = catfile($pensource, 'public', $config->{_default}->{root}, 'index.html');
  $root_index->process('main.tt2', $vars, $index, { binmode => ':utf8' })
      || die $root_index->error(), "\n";

return 1;
}

1;
