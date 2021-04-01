use strict;
use warnings;
package IO::TieCombine;
# ABSTRACT: produce tied (and other) separate but combined variables
$IO::TieCombine::VERSION = '1.005';
use Carp ();
use IO::TieCombine::Handle;
use IO::TieCombine::Scalar;
use Symbol ();

#pod =head1 SYNOPSIS
#pod
#pod First, we set up a bunch of access points:
#pod
#pod   my $hub = IO::TieCombine->new;
#pod
#pod   my $str_ref  = $hub->scalar_ref('x');
#pod   my $fh       = $hub->fh('x');
#pod   my $callback = $hub->callback('x');
#pod
#pod   tie my $scalar, $hub, 'x';
#pod   tie local *STDOUT, $hub, 'x';
#pod
#pod   tie local *STDERR, $hub, 'err';
#pod
#pod Then we write to things:
#pod
#pod   $$str_ref .= 'And ';
#pod   print $fh "now ";
#pod   $callback->('for ');
#pod   $scalar .= 'something ';
#pod   print "completely ";
#pod   warn "different.\n";
#pod
#pod And then:
#pod
#pod   $hub->combined_contents;    # And now for something completely different.
#pod   $hub->slot_contents('x');   # And now for something completely
#pod   $hub->slot_contents('err'); # different.
#pod
#pod B<ACHTUNG!!>  Because of a serious problem with Perl 5.10.0, output sent to a
#pod tied filehandle using C<say> B<will not have the expected newline>.  5.10.1 or
#pod later is needed.  Since 5.10.0 is broken in so many other ways, you should
#pod really upgrade anyway.
#pod
#pod B<ACHTUNG!!>  Because of a different problem with Perls 5.10.1 - 5.16.3, if you
#pod send output to a tied filehandle using C<say>, and C<$\> is undefined (which is
#pod the default), B<< C<$\> will not be restored to C<undef> after the C<say> >>!
#pod This means that once you've used C<say> to print to I<any> tied filehandle, you
#pod have corrupted the global state of your program.  Either start your program by
#pod setting C<$\> to an empty string, which should be safe, or upgrade to 5.18.0.
#pod
#pod =cut

#pod =method new
#pod
#pod The constructor takes no arguments.
#pod
#pod =cut

sub new {
  my ($class) = @_;

  my $self = {
    combined => \(my $str = ''),
    slots    => { },
  };

  bless $self => $class;
}

#pod =method combined_contents
#pod
#pod This method returns the contents of all collected data.
#pod
#pod =cut

sub combined_contents {
  my ($self) = @_;
  return ${ $self->{combined} };
}

#pod =method slot_contents
#pod
#pod   my $str = $hub->slot_contents( $slot_name );
#pod
#pod This method returns the contents of all collected data for the named slot.
#pod
#pod =cut

sub slot_contents {
  my ($self, $name) = @_;
  Carp::confess("no name provided for slot_contents") unless defined $name;

  Carp::confess("no such output slot exists")
    unless exists $self->{slots}{$name};

  return ${ $self->{slots}{$name} };
}

sub _slot_ref {
  my ($self, $name) = @_;
  Carp::confess("no slot name provided") unless defined $name;

  $self->{slots}{$name} = \(my $str = '') unless $self->{slots}{$name};
  return $self->{slots}{$name};
}

sub _tie_args {
  my ($self, $name) = @_;
  return {
    slot_name    => $name,
    combined_ref => $self->{combined},
    output_ref   => $self->_slot_ref($name),
  };
}

#pod =method clear_slot
#pod
#pod   $hub->clear_slot( $slot_name );
#pod
#pod This sets the slot back to an empty string.
#pod
#pod =cut

sub clear_slot {
  my ($self, $slot_name) = @_;
  ${ $self->_slot_ref($slot_name) } = '';
  return;
}

#pod =method fh
#pod
#pod   my $fh = $hub->fh( $slot_name );
#pod
#pod This method returns a reference to a tied filehandle.  When printed to, output
#pod is collected in the named slot.
#pod
#pod =cut

sub fh {
  my ($self, $name) = @_;

  my $sym = Symbol::gensym;
  my ($class, @rest) = $self->_tie_fh_args($name);
  tie *$sym, $class, @rest;
  return $sym;
}

sub TIEHANDLE {
  my ($self, @args) = @_;
  my ($class, @rest) = $self->_tie_fh_args(@args);

  return $class->TIEHANDLE(@rest);
}

sub _tie_fh_args {
  my ($self, $name) = @_;
  return ('IO::TieCombine::Handle', $self->_tie_args($name));
}

#pod =method scalar_ref
#pod
#pod   my $str_ref = $hub->scalar_ref( $slot_name );
#pod
#pod This method returns a reference to scalar.  When appended to, the new content
#pod is collected in the named slot.  Attempting to alter the string other than by
#pod adding new content to its end will result in an exception.
#pod
#pod =cut

sub scalar_ref {
  my ($self, $name) = @_;
  my ($class, @rest) = $self->_tie_scalar_args($name);
  tie my($tie), $class, @rest;
  return \$tie;
}

sub TIESCALAR {
  my ($self, @args) = @_;
  my ($class, @rest) = $self->_tie_scalar_args(@args);

  return $class->TIESCALAR(@rest);
}

sub _tie_scalar_args {
  my ($self, $name) = @_;
  return ('IO::TieCombine::Scalar', $self->_tie_args($name));
}

#pod =method callback
#pod
#pod   my $code = $hub->callback( $slot_name );
#pod
#pod =cut

sub callback {
  my ($self, $name) = @_;
  my $slot = $self->_slot_ref($name);
  return sub {
    my ($value) = @_;

    ${ $slot             } .= $value;
    ${ $self->{combined} } .= $value;
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

IO::TieCombine - produce tied (and other) separate but combined variables

=head1 VERSION

version 1.005

=head1 SYNOPSIS

First, we set up a bunch of access points:

  my $hub = IO::TieCombine->new;

  my $str_ref  = $hub->scalar_ref('x');
  my $fh       = $hub->fh('x');
  my $callback = $hub->callback('x');

  tie my $scalar, $hub, 'x';
  tie local *STDOUT, $hub, 'x';

  tie local *STDERR, $hub, 'err';

Then we write to things:

  $$str_ref .= 'And ';
  print $fh "now ";
  $callback->('for ');
  $scalar .= 'something ';
  print "completely ";
  warn "different.\n";

And then:

  $hub->combined_contents;    # And now for something completely different.
  $hub->slot_contents('x');   # And now for something completely
  $hub->slot_contents('err'); # different.

B<ACHTUNG!!>  Because of a serious problem with Perl 5.10.0, output sent to a
tied filehandle using C<say> B<will not have the expected newline>.  5.10.1 or
later is needed.  Since 5.10.0 is broken in so many other ways, you should
really upgrade anyway.

B<ACHTUNG!!>  Because of a different problem with Perls 5.10.1 - 5.16.3, if you
send output to a tied filehandle using C<say>, and C<$\> is undefined (which is
the default), B<< C<$\> will not be restored to C<undef> after the C<say> >>!
This means that once you've used C<say> to print to I<any> tied filehandle, you
have corrupted the global state of your program.  Either start your program by
setting C<$\> to an empty string, which should be safe, or upgrade to 5.18.0.

=head1 METHODS

=head2 new

The constructor takes no arguments.

=head2 combined_contents

This method returns the contents of all collected data.

=head2 slot_contents

  my $str = $hub->slot_contents( $slot_name );

This method returns the contents of all collected data for the named slot.

=head2 clear_slot

  $hub->clear_slot( $slot_name );

This sets the slot back to an empty string.

=head2 fh

  my $fh = $hub->fh( $slot_name );

This method returns a reference to a tied filehandle.  When printed to, output
is collected in the named slot.

=head2 scalar_ref

  my $str_ref = $hub->scalar_ref( $slot_name );

This method returns a reference to scalar.  When appended to, the new content
is collected in the named slot.  Attempting to alter the string other than by
adding new content to its end will result in an exception.

=head2 callback

  my $code = $hub->callback( $slot_name );

=head1 AUTHOR

Ricardo SIGNES <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
