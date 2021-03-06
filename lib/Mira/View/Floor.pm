package Mira::View::Floor;
$Mira::View::Floor::VERSION = '00.07.56';

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

    my $allposts     = $switches{posts}; #all utids reverse sorted
    my $allentries   = $switches{allentries}; #all entries data hash
    my $floors       = $switches{floors};
    my $config       = $switches{config}; #configs
    my $pensource    = $switches{pensource};
    my $archives     = $switches{archives};
    my $floor_data   = $switches{floor_data};
    my $build        = $switches{build};
    my $address_base = $switches{address_base};



    foreach my $floor (keys %$floors)
    {
        my $floor_template_root;
        if
        (-f catfile($pensource,'template',$config->{$floor}->{template},'index.tt2'))
        {
            $floor_template_root =
            catdir($pensource,'template',$config->{$floor}->{template})
        } elsif
        (-f catfile($pensource,'template',$config->{_default}->{template},'index.tt2'))
        {
            $floor_template_root =
            catdir($pensource,'template', $config->{_default}->{template})
        } else
        {
            next;
        }


        my @utids = @{$floors->{$floor}};
        @utids = ($config->{$floor}->{post_sort} and $config->{$floor}->{post_sort} eq 'reverse') ? sort @utids : reverse sort @utids;
        @utids = grep {
            not $allentries->{$_}->{_type} or $allentries->{$_}->{_type} !~ m/^(page|draft)$/
        } @utids;

#        my $floor_index = Template->new({
#            INCLUDE_PATH => [ $floor_template_root, catdir($floor_template_root, 'include') ],
#            INTERPOLATE  => 1,
#            TRIM      => 1,
#            EVAL_PERL => 1,
#            ENCODING => 'utf8',
#            START_TAG => quotemeta($config->{$floor}->{t_start_tag}),
#            END_TAG   => quotemeta($config->{$floor}->{t_end_tag}),
#            OUTLINE_TAG => quotemeta( $config->{$floor}->{t_outline_tag} ),
#        }) || die "$Template::ERROR\n";

        my $vars = {
            PageTITLE       => $config->{$floor}->{title},
            IS_INDEX        => 'true',

            ENTRIES         => $allentries,
            FLOORS          => $floor_data,
            ARCHIVES        => {
                %{$archives->{$floor}->{list}},
                %{$archives->{$floor}->{date}}
            },

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

        my $floor_post_num = ($config->{$floor}->{post_num} eq 'all') ?
            scalar @utids : $config->{$floor}->{post_num};
        my $page_number = 1;
        my $page_total;
        if (@utids and (scalar @utids) % ($floor_post_num) == 0)
        {
            $page_total = (scalar @utids) / ($floor_post_num);
        } elsif (@utids and (scalar @utids) % ($floor_post_num) != 0)
        {
            $page_total = int( (scalar @utids) / ($floor_post_num) ) + 1;
        }

        while (my @pagepost = splice @utids, 0, $floor_post_num)
        {
            my $page = {};
            my $posts = [];
            foreach my $utid (@pagepost)
            {
                push @$posts, $allentries->{$utid};
            }
            $vars->{POSTS} = $posts;

            my $ext = $config->{$floor}->{output_extension} || 'html';
            $ext =~ s{^\.+}{};
            my $target = $page_number == 1 ? "index.$ext" : "/page/$page_number/index.$ext";
            my $index = catfile($pensource, $config->{_default}->{publishDIR}, $config->{$floor}->{root}, $target);

            $page->{next}->{url} = @utids ? "$config->{$floor}->{root}/page/" . ($page_number+1) . "/" : '' ;
            $page->{next}->{url} =~ s{^(.*?):/+|/+}{/}g if ($page->{next}->{url});
            $page->{next}->{title} = ($page_number+1) if $page->{next}->{url};
            delete $page->{next} unless $page->{next}->{url};

            $page->{prev}->{url} = $page_number == 1 ? '' : "$config->{$floor}->{root}/page/" . ($page_number-1) . "/" ;
            $page->{prev}->{url} = $config->{$floor}->{root} . "/" if $page_number == 2;
            $page->{prev}->{url} =~ s{^(.*?):/+|/+}{/}g if ($page->{prev}->{url});
            $page->{prev}->{title} = ($page_number-1) if $page->{prev}->{url};
            delete $page->{prev} unless $page->{prev}->{url};

            $page->{number} = $page_number;
            $page->{total} = $page_total;
            $vars->{PAGE} = $page;

            $address_base->add(
                url           => $config->{$floor}->{root},
                variables     => $vars,
                template_root => $floor_template_root,
                template_file => 'index.tt2',
                output        => $index,
                START_TAG     => quotemeta($config->{$floor}->{t_start_tag}),
                END_TAG       => quotemeta($config->{$floor}->{t_end_tag}),
                OUTLINE_TAG   => quotemeta($config->{$floor}->{t_outline_tag}),
            );

#            $floor_index->process('index.tt2', $vars, $index, { binmode => ':utf8' })
#            || die $floor_index->error(), "\n";
            $page_number++;
        }

    }


}

1;


#MainTITLE       => $config->{_default}->{title},
#MainDESCRIPTION => $config->{_default}->{description},
#MainURL         => $config->{_default}->{url},
#MainROOT        => $config->{_default}->{root},
#MainSTATIC      => $config->{_default}->{static},
#MainIMAGEURL    => $config->{_default}->{imageurl},
#MainAUTHOR      => $config->{_default}->{author},
#MainEMAIL       => $config->{_default}->{email},
#TITLE           => $config->{$floor}->{title},
#DESCRIPTION     => $config->{$floor}->{description},
#URL             => $config->{$floor}->{url},
#ROOT            => $config->{$floor}->{root},
#STATIC          => $config->{$floor}->{static},
#IMAGEURL        => $config->{$floor}->{imageurl},
#AUTHOR          => $config->{$floor}->{author},
#EMAIL           => $config->{$floor}->{email},
