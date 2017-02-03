package Mira;

use strict;
use warnings;
use 5.012;
our $VERSION = '0.05';

use Mira::Parser;
use Mira::Field;
use Mira::Data;
use Mira::Date;
use Mira::Config;
use Mira::Exception;
use Mira::View;
use Mira::CLI;


1;
__END__

=pod

=encoding utf8

=head1 NAME

Mira - module used for 'mira' site generator

=head1 VERSION

This document describes L<Mira> version B<0.05>.

=head1 NOTE

mira is a multiple static generator which use Mira modules

=head1 AUTHOR

kiavash <kiavash@cpan.org>

=head1 COPYRIGHT AND LICENSE

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
