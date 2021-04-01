use strict;
use warnings;
package IO::TieCombine::Scalar;
# ABSTRACT: tied scalars for IO::TieCombine
$IO::TieCombine::Scalar::VERSION = '1.005';
use Carp ();

sub TIESCALAR {
  my ($class, $arg) = @_;

  my $self = {
    slot_name    => $arg->{slot_name},
    combined_ref => $arg->{combined_ref},
    output_ref   => $arg->{output_ref},
  };

  bless $self => $class;
}

sub FETCH {
  return ${ $_[0]->{output_ref} }
}

sub STORE {
  my ($self, $value) = @_;
  my $class = ref $self;
  my $output_ref = $self->{output_ref};

  Carp::croak "you may only append, not reassign, a $class tie"
    unless index($value, $$output_ref) == 0;
  
  my $extra = substr $value, length $$output_ref, length $value;

  ${ $self->{combined_ref} } .= $extra;
  return ${ $self->{output_ref} } = $value;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

IO::TieCombine::Scalar - tied scalars for IO::TieCombine

=head1 VERSION

version 1.005

=head1 AUTHOR

Ricardo SIGNES <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
