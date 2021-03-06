package Mira::View::Archive;
$Mira::View::Archive::VERSION = '00.07.56';

use strict;
use warnings;
use utf8;
use 5.012;

use File::Spec;
use File::Spec::Functions;
use Template;

sub template {
    my $class    = shift;
    my %switches = @_;

    my $allposts   = $switches{posts};         #all utids reverse sorted
    my $allentries = $switches{allentries};    #all entries data hash

    #  my $floors = $switches{floors};
    my $config     = $switches{config};        #configs
    my $pensource  = $switches{pensource};
    my $archives   = $switches{archives};
    my $floor_data = $switches{floor_data};
    my $build      = $switches{build};
    my $address_base = $switches{address_base};

    foreach my $floor ( keys %$archives )
    {
        my $arch_stct = {
            %{ $archives->{$floor}->{list} },
            %{ $archives->{$floor}->{date} }
        };
        foreach my $archive ( keys %$arch_stct )
        {
            my $archive_template_root;
            if (
                -f catfile(
                    $pensource,                    'template',
                    $config->{$floor}->{template}, 'archive.tt2'
                )
                or
                -f catfile(
                    $pensource,                    'template',
                    $config->{$floor}->{template}, "$archive.tt2"
                )
              )
            {
                $archive_template_root = catdir(
                    $pensource, 'template',
                    $config->{$floor}->{template}
                );
            }
            elsif (
                -f catfile(
                    $pensource,                    'template',
                    $config->{$floor}->{template}, 'archive.tt2'
                )
                or
                -f catfile(
                    $pensource,                    'template',
                    $config->{$floor}->{template}, "$archive.tt2"
                )
              )
            {
                $archive_template_root = catdir(
                    $pensource, 'template',
                    $config->{_default}->{template}
                );
            }
            else
            {
                next;
            }

            foreach my $list ( keys %{ $arch_stct->{$archive} } )
            {
                my $show_list_url = $arch_stct->{$archive}->{$list}->{url};
                my @show_list_address = split( m:/:, $show_list_url );
                my @utids = @{ $arch_stct->{$archive}->{$list}->{posts} };
                @utids = ($config->{$floor}->{post_sort} and $config->{$floor}->{post_sort} eq 'reverse') ? sort @utids : reverse sort @utids;
                @utids = grep {
                    not $allentries->{$_}->{_type} or $allentries->{$_}->{_type} !~ m/^(page|draft)$/
                } @utids;

#                my $archive_index = Template->new(
#                {
#                    INCLUDE_PATH => [
#                        $archive_template_root,
#                        catdir( $archive_template_root, 'include' )
#                    ],
#                    INTERPOLATE => 1,
#                    TRIM      => 1,
#                    EVAL_PERL => 1,
#                    ENCODING    => 'utf8',
#                    START_TAG   => quotemeta( $config->{$floor}->{t_start_tag} ),
#                    END_TAG     => quotemeta( $config->{$floor}->{t_end_tag} ),
#                    OUTLINE_TAG => quotemeta( $config->{$floor}->{t_outline_tag} ),
#                }) || die "$Template::ERROR\n";

                my $vars = {
                    ArchiveTITLE => $list,
                    PageTITLE    => "$config->{$floor}->{title} - $list",

                    ENTRIES  => $allentries,
                    FLOORS   => $floor_data,
                    ARCHIVES => {
                        %{ $archives->{$floor}->{list} },
                        %{ $archives->{$floor}->{date} }
                    },    #$archives->{$floor}->{list},

                    ARCH => $arch_stct->{$archive}->{$list},

                    MAIN  => $config->{_default},
                    SITE  => $config->{$floor},
                    BUILD => $build,

                    FarsiNum => bless( \&farsinum, 'mira' ),
                };

                sub farsinum {
                    my $string = shift;
                    $string =~ tr/1234567890/۱۲۳۴۵۶۷۸۹۰/;
                    return $string;
                }

                if ( $arch_stct->{$archive}->{$list}->{year} )
                {
                    $vars->{ArchiveTITLE} =
                        $arch_stct->{$archive}->{$list}->{year}
                        ."/"
                        .$arch_stct->{$archive}->{$list}->{month};
                    $vars->{PageTITLE} =
                        $config->{$floor}->{title}
                        ." - "
                        .$arch_stct->{$archive}->{$list}->{year}
                        ."/"
                        .$arch_stct->{$archive}->{$list}->{month};
                    $vars->{IS_DATE_ARCHIVE} = 'true';
                }
                else
                {
                    $vars->{IS_ARCHIVE} = 'true';
                }

                foreach my $field ( keys %{ $archives->{$floor}->{list} } )
                {
                    $vars->{ uc($field) . "_ARCHIVE" } = [
                        reverse sort {
                            $#{ $a->{posts} } <=> $#{ $b->{posts} }
                            or $a->{name} cmp $b->{name}
                        } ( values %{ $archives->{$floor}->{list}->{$field} } )
                    ];
                }

                foreach my $field ( keys %{ $archives->{$floor}->{date} } ) {
                    $vars->{ uc($field) . "_ARCHIVE" } = [
                        reverse sort {
                                 $a->{_year} <=> $b->{_year}
                              or $a->{_number} <=> $b->{_number}
                          } (
                            values %{ $archives->{$floor}->{date}->{$field} } )
                    ];
                }

                my $archive_post_num =
                  ( $config->{$floor}->{archive_post_num} eq 'all' )
                  ? scalar @utids
                  : $config->{$floor}->{archive_post_num};
                my $page_number = 1;
                my $page_total;
                if ( ( scalar @utids ) % ($archive_post_num) == 0 )
                {
                    $page_total = ( scalar @utids ) / ($archive_post_num);
                } else
                {
                    $page_total =
                        int( ( scalar @utids ) / ($archive_post_num) ) + 1;
                }
                while ( my @pagepost = splice @utids, 0, $archive_post_num )
                {
                    my $page  = {};
                    my $posts = [];
                    foreach my $utid (@pagepost)
                    {
                        push @$posts, $allentries->{$utid};
                    }
                    $vars->{POSTS} = $posts;

                    my $ext = $config->{$floor}->{output_extension} || 'html';
                    $ext =~ s{^\.+}{};
                    my $target =
                        $page_number == 1
                        ? "index.$ext"
                        : "/page/$page_number/index.$ext";
                    my $index =
                        catfile( $pensource, $config->{_default}->{publishDIR},
                        @show_list_address, $target );

					my $archive_url =
						$config->{$floor}->{url} .
						$arch_stct->{$archive}->{$list}->{url}
					;
					$archive_url =~ s{(?<!:)/+}{/}g;

                    $page->{next}->{url} =
                        @utids
                        ?   "$show_list_url/page/"
                            . ( $page_number + 1 )
                            . "/index.$ext"
                        : '';
                    $page->{next}->{url} =~ s{^(.*?):/+|/+}{/}g
                        if $page->{next}->{url};
                    $page->{next}->{title} = ( $page_number + 1 )
                        if $vars->{next}->{url};
                    delete $page->{next} unless $page->{next}->{url};

                    $page->{prev}->{url} =
                        $page_number == 1
                        ? ''
                        :   "$show_list_url/page/"
                            . ( $page_number - 1 )
                            . "/index.$ext";
                    $page->{prev}->{url} = "$show_list_url/index.$ext"
                        if $page_number == 2;
                    $page->{prev}->{url} =~ s{^(.*?):/+|/+}{/}g
                        if $page->{prev}->{url};
                    $page->{prev}->{title} = ( $page_number - 1 )
                        if $vars->{prev}->{url};
                    delete $page->{prev} unless $page->{prev}->{url};

                    $page->{number} = $page_number;
                    $page->{total}  = $page_total;
                    $vars->{PAGE}   = $page;

                    my $arch_template =
                      ( -f catfile( $archive_template_root, "$archive.tt2" ) )
                      ? "$archive.tt2"
                      : "archive.tt2";

                    $address_base->add(
                        url           => $archive_url,
                        variables     => $vars,
                        template_root => $archive_template_root,
                        template_file => $arch_template,
                        output        => $index,
                        START_TAG     => quotemeta($config->{$floor}->{t_start_tag}),
                        END_TAG       => quotemeta($config->{$floor}->{t_end_tag}),
                        OUTLINE_TAG   => quotemeta($config->{$floor}->{t_outline_tag}),
                    );
#                    $archive_index->process( $arch_template, $vars, $index,
#                        { binmode => ':utf8' } )
#                      || die $archive_index->error(), "\n";
                    $page_number++;
                }
            }
        }
    }

}

1;
