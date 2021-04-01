use strict;
use warnings;
package IO::TieCombine::Handle;
# ABSTRACT: tied filehandles for IO::TieCombine
$IO::TieCombine::Handle::VERSION = '1.005';
use Carp ();

sub TIEHANDLE {
  my ($class, $arg) = @_;

  my $self = {
    slot_name    => $arg->{slot_name},
    combined_ref => $arg->{combined_ref},
    output_ref   => $arg->{output_ref},
  };

  return bless $self => $class;
}

sub PRINT {
  my ($self, @output) = @_;

  my $joined = join((defined $, ? $, : q{}), @output)
             . (defined $\ ? $\ : q{});

  ${ $self->{output_ref}   } .= $joined;
  ${ $self->{combined_ref} } .= $joined;

  return 1;
}

sub PRINTF {
  my $self = shift;
  my $fmt  = shift;
  $self->PRINT(sprintf($fmt, @_));
}

sub OPEN     { return $_[0] }
sub BINMODE  { return 1; }
sub FILENO   { return 0 - $_[0] }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

IO::TieCombine::Handle - tied filehandles for IO::TieCombine

=head1 VERSION

version 1.005

=head1 AUTHOR

Ricardo SIGNES <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
