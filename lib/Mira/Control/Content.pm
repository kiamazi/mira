package Mira::Control::Content;
$Mira::Control::Content::VERSION = '00.07.56';

use strict;
use warnings;
use 5.012;


sub preparator {

    say "v1.00.00";
    my $class = shift;
    my %switches = @_;

    my $source      = $switches{source};
    my $floorsource = $switches{floorsource};
    my $ext         = $switches{ext}; # ? $switches{ext} : '.draft';
    my $config      = $switches{config};


    ######################
    use Mira::Model::Base;
    my $data = Mira::Model::Base->new;
    ######################
    use Mira::Model::Floor;
    my $floors_data = Mira::Model::Floor->new;


    ######################
    use Mira::Control::Content::Load;

    my $content = Mira::Control::Content::Load->new(
        source      => $source,
        ext         => $ext,
        floorsource => $floorsource,
    );
    my $floors  = $content->floors;
    my $files   = $content->files($floors);
    my $statics = $content->statics($floors);


    ######################
    use Mira::Control::Parser::Entry;
    use Mira::Control::Parser::Markup;
#    use Mira::Control::Parser::img;
    use Mira::Control::Content::Date;

#parallel::fork    use Parallel::ForkManager;

    foreach my $floor (@$floors)
    {
#parallel::fork        my $pm = Parallel::ForkManager->new( 4000 );
#parallel::fork        $pm->set_waitpid_blocking_sleep(0);
#parallel::fork        $pm->run_on_finish( sub {
#parallel::fork            my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_ref) = @_;
#parallel::fork            my $utid  = $data_ref->{utid};
#parallel::fork            my $values = $data_ref->{values};
#parallel::fork            if (not exists $data->{$utid})
#parallel::fork            {
#parallel::fork                $data->add($utid, $values);
#parallel::fork                $floors_data->add($floor, $utid);
#parallel::fork            }
#parallel::fork        });
#parallel::fork
        foreach my $file (@{$files->{$floor}})
        {
#            $pm->start and next;

            my $parser = Mira::Control::Parser::Entry->parse(entry => $file, floor => $floor);
            next unless $parser;

            my $utid = $parser->{utid};
            my $values = $parser->{values};
            if (not exists $data->{$utid})
            {
                Mira::Control::Content::Date->date($values, $config->{$floor}->{timezone});

#                $values->{body} = Mira::Control::Parser::img->replace(
#                    $values->{body},
#                    _img_url($floor, $config),
#                    $config,
#                );
                $values->{body} = Mira::Control::Parser::Markup->markup(
                    $values->{body},
                    _markup_lang($values, $config),
                    $config,
                );
                $data->add($utid, $values);
                $floors_data->add($floor, $utid);
            } else
            {
                say "this files have same utid, plz fix it :\n"
                    .">". $file
                    .">". $data->{$utid}->{SPEC}->{file_address}
                ."\n";
            }
#parallel::fork            $pm->finish(0, { utid => $utid, values => $values });
        }
#parallel::fork        $pm->wait_all_children;
    }


    ######################
    use Mira::Control::Content::Address;
    Mira::Control::Content::Address->address($data, $config);

    ######################
    use Mira::Model::Archive;
    my $archive_base = Mira::Model::Archive->lists($data, $config);

    ######################
#    use Mira::Model::Address;
#    my $address_base = Mira::Model::Address->new;


    my $self = {
        data  => { %$data },
        floor => { %$floors_data },
        archive  => $archive_base,
        statics => $statics,
    };
    return $self;

}



sub _markup_lang {
    my $post = shift;
    my $floor = $post->{floor};
    my $config = shift;
    my $markup_lang;

    $markup_lang = $post->{_markup} if $post->{_markup};
    $markup_lang = $config->{$floor}->{default_markup}
    if (not $markup_lang and $config->{$floor}->{default_markup});
    $markup_lang = $config->{_default}->{default_markup}
    if (not $markup_lang and $config->{_default}->{default_markup});
    $markup_lang = 'markmod' if not $markup_lang;

    return $markup_lang;
}


sub _img_url {
    my $floor = shift;
    my $config = shift;
    my $imgurl;
    if ($config->{$floor} and $config->{$floor}->{imageurl})
    {
    $imgurl = $config->{$floor}->{imageurl};
    } elsif ($config->{_default}->{imageurl})
    {
    $imgurl = $config->{_default}->{imageurl};
    } elsif ($config->{$floor} and $config->{$floor}->{root})
    {
    $imgurl = "/$config->{$floor}->{root}/static/img/";
    } else
    {
    $imgurl = "/$floor/static/img/";
    }
    $imgurl =~ s:/+:/:g;
    return $imgurl;
}



1;
__END__

=head1 NAME
Mira Static site generator
