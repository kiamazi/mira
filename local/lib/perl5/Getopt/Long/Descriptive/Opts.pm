use strict;
use warnings;
package Getopt::Long::Descriptive::Opts;
# ABSTRACT: object representing command line switches
$Getopt::Long::Descriptive::Opts::VERSION = '0.102';
use Scalar::Util qw(blessed weaken);

#pod =head1 DESCRIPTION
#pod
#pod This class is the base class of all C<$opt> objects returned by
#pod L<Getopt::Long::Descriptive>.  In general, you do not want to think about this
#pod class, look at it, or alter it.  Seriously, it's pretty dumb.
#pod
#pod Every call to C<describe_options> will return a object of a new subclass of
#pod this class.  It will have a method for the canonical name of each option
#pod possible given the option specifications.
#pod
#pod Method names beginning with an single underscore are public, and are named that
#pod way to avoid conflict with automatically generated methods.  Methods with
#pod multiple underscores (in case you're reading the source) are private.
#pod
#pod =head1 METHODS
#pod
#pod B<Achtung!>  All methods beginning with an underscore are experimental as of
#pod today, 2009-12-12.  They are likely to be formally made permanent soon.
#pod
#pod =head2 _specified
#pod
#pod This method returns true if the given name was specified on the command line.
#pod
#pod For example, if C<@ARGS> was "C<< --foo --bar 10 >>" and C<baz> is defined by a
#pod default, C<_specified> will return true for foo and bar, and false for baz.
#pod
#pod =cut

my %_CREATED_OPTS;
my $SERIAL_NUMBER = 1;

sub _specified {
  my ($self, $name) = @_;
  my $meta = $_CREATED_OPTS{ blessed $self }{meta};
  return $meta->{given}{ $name };
}

#pod =head2 _specified_opts
#pod
#pod This method returns an opt object in which only explicitly specified values are
#pod defined.  Values which were set by defaults will appear undef.
#pod
#pod =cut

sub _specified_opts {
  my ($self) = @_;

  my $class = blessed $self;
  my $meta = $_CREATED_OPTS{ $class  }{meta};

  return $meta->{specified_opts} if $meta->{specified_opts};

  my @keys = grep { $meta->{given}{ $_ } } (keys %{ $meta->{given} });

  my %opts;
  @opts{ @keys } = @$self{ @keys };

  $meta->{specified_opts} = \%opts;

  bless $meta->{specified_opts} => $class;
  weaken $meta->{specified_opts};

  $meta->{specified_opts};
}

#pod =head2 _complete_opts
#pod
#pod This method returns the opts object with all values, including those set by
#pod defaults.  It is probably not going to be very often-used.
#pod
#pod =cut

sub _complete_opts {
  my ($self) = @_;

  my $class = blessed $self;
  my $meta = $_CREATED_OPTS{ $class  }{meta};
  return $meta->{complete_opts};
}

sub ___class_for_opt {
  my ($class, $arg) = @_;

  my $values = $arg->{values};
  my @bad = grep { $_ !~ /^[a-z_]\w*$/ } keys %$values;
  Carp::confess("perverse option names given: @bad") if @bad;

  my $new_class = "$class\::__OPT__::" . $SERIAL_NUMBER++;
  $_CREATED_OPTS{ $new_class } = { meta => $arg };

  {
    no strict 'refs';
    ${"$new_class\::VERSION"} = $class->VERSION;
    *{"$new_class\::ISA"} = [ 'Getopt::Long::Descriptive::Opts' ];
    for my $opt (keys %$values) {
      *{"$new_class\::$opt"} = sub { $_[0]->{ $opt } };
    }
  }

  return $new_class;
}

sub ___new_opt_obj {
  my ($class, $arg) = @_;

  my $copy = { %{ $arg->{values} } };

  my $new_class = $class->___class_for_opt($arg);

  # This is stupid, but the traditional behavior was that if --foo was not
  # given, there is no $opt->{foo}; it started to show up when we "needed" all
  # the keys to generate a class, but was undef; this wasn't a problem, but
  # broke tests of things that were relying on not-exists like tests of %$opt
  # contents or MooseX::Getopt which wanted to use things as args for new --
  # undef would not pass an Int TC.  Easier to just do this. -- rjbs,
  # 2009-11-27
  delete $copy->{$_} for grep { ! defined $copy->{$_} } keys %$copy;

  my $self = bless $copy => $new_class;

  $_CREATED_OPTS{ $new_class }{meta}{complete_opts} = $self;
  # weaken $_CREATED_OPTS{ $new_class }{meta}{complete_opts};

  return $self;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Getopt::Long::Descriptive::Opts - object representing command line switches

=head1 VERSION

version 0.102

=head1 DESCRIPTION

This class is the base class of all C<$opt> objects returned by
L<Getopt::Long::Descriptive>.  In general, you do not want to think about this
class, look at it, or alter it.  Seriously, it's pretty dumb.

Every call to C<describe_options> will return a object of a new subclass of
this class.  It will have a method for the canonical name of each option
possible given the option specifications.

Method names beginning with an single underscore are public, and are named that
way to avoid conflict with automatically generated methods.  Methods with
multiple underscores (in case you're reading the source) are private.

=head1 METHODS

B<Achtung!>  All methods beginning with an underscore are experimental as of
today, 2009-12-12.  They are likely to be formally made permanent soon.

=head2 _specified

This method returns true if the given name was specified on the command line.

For example, if C<@ARGS> was "C<< --foo --bar 10 >>" and C<baz> is defined by a
default, C<_specified> will return true for foo and bar, and false for baz.

=head2 _specified_opts

This method returns an opt object in which only explicitly specified values are
defined.  Values which were set by defaults will appear undef.

=head2 _complete_opts

This method returns the opts object with all values, including those set by
defaults.  It is probably not going to be very often-used.

=head1 AUTHORS

=over 4

=item *

Hans Dieter Pearcey <hdp@cpan.org>

=item *

Ricardo Signes <rjbs@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2005 by Hans Dieter Pearcey.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
