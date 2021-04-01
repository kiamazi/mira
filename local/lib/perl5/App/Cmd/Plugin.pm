use strict;
use warnings;
package App::Cmd::Plugin;
$App::Cmd::Plugin::VERSION = '0.331';
# ABSTRACT: a plugin for App::Cmd commands

sub _faux_curried_method {
  my ($class, $name, $arg) = @_;

  return sub {
    my $cmd = $App::Cmd::active_cmd;
    $class->$name($cmd, @_);
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Cmd::Plugin - a plugin for App::Cmd commands

=head1 VERSION

version 0.331

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
