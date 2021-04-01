use strict;
use warnings;
package Getopt::Long::Descriptive;
# ABSTRACT: Getopt::Long, but simpler and more powerful
$Getopt::Long::Descriptive::VERSION = '0.102';
use Carp qw(carp croak);
use File::Basename ();
use Getopt::Long 2.33;
use List::Util qw(first);
use Params::Validate 0.97 qw(:all);
use Scalar::Util ();

use Getopt::Long::Descriptive::Opts;
use Getopt::Long::Descriptive::Usage;

#pod =head1 SYNOPSIS
#pod
#pod   use Getopt::Long::Descriptive;
#pod
#pod   my ($opt, $usage) = describe_options(
#pod     'my-program %o <some-arg>',
#pod     [ 'server|s=s', "the server to connect to", { required => 1  } ],
#pod     [ 'port|p=i',   "the port to connect to",   { default  => 79 } ],
#pod     [],
#pod     [ 'verbose|v',  "print extra stuff"            ],
#pod     [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
#pod   );
#pod
#pod   print($usage->text), exit if $opt->help;
#pod
#pod   Client->connect( $opt->server, $opt->port );
#pod
#pod   print "Connected!\n" if $opt->verbose;
#pod
#pod ...and running C<my-program --help> will produce:
#pod
#pod   my-program [-psv] [long options...] <some-arg>
#pod     -s --server     the server to connect to
#pod     -p --port       the port to connect to
#pod
#pod     -v --verbose    print extra stuff
#pod     --help          print usage message and exit
#pod
#pod =head1 DESCRIPTION
#pod
#pod Getopt::Long::Descriptive is yet another Getopt library.  It's built atop
#pod Getopt::Long, and gets a lot of its features, but tries to avoid making you
#pod think about its huge array of options.
#pod
#pod It also provides usage (help) messages, data validation, and a few other useful
#pod features.
#pod
#pod =head1 FUNCTIONS
#pod
#pod Getopt::Long::Descriptive only exports one routine by default:
#pod C<describe_options>.  All GLD's exports are exported by L<Sub::Exporter>.
#pod
#pod =head2 describe_options
#pod
#pod   my ($opt, $usage) = describe_options($usage_desc, @opt_spec, \%arg);
#pod
#pod This routine inspects C<@ARGV> for options that match the supplied spec. If all
#pod the options are valid then it returns the options given and an object for
#pod generating usage messages; if not then it dies with an explanation of what was
#pod wrong and a usage message.
#pod
#pod The C<$opt> object will be a dynamically-generated subclass of
#pod L<Getopt::Long::Descriptive::Opts>.  In brief, each of the options in
#pod C<@opt_spec> becomes an accessor method on the object, using the first-given
#pod name, with dashes converted to underscores.  For more information, see the
#pod documentation for the Opts class.
#pod
#pod The C<$usage> object will be a L<Getopt::Long::Descriptive::Usage> object,
#pod which provides a C<text> method to get the text of the usage message and C<die>
#pod to die with it.  For more methods and options, consults the documentation for
#pod the Usage class.
#pod
#pod =head3 $usage_desc
#pod
#pod The C<$usage_desc> parameter to C<describe_options> is a C<sprintf>-like string
#pod that is used in generating the first line of the usage message.  It's a
#pod one-line summary of how the command is to be invoked.  A typical usage
#pod description might be:
#pod
#pod   $usage_desc = "%c %o <source> <desc>";
#pod
#pod C<%c> will be replaced with what Getopt::Long::Descriptive thinks is the
#pod program name (it's computed from C<$0>, see L</prog_name>).
#pod
#pod C<%o> will be replaced with a list of the short options, as well as the text
#pod "[long options...]" if any have been defined.
#pod
#pod The rest of the usage description can be used to summarize what arguments are
#pod expected to follow the program's options, and is entirely free-form.
#pod
#pod Literal C<%> characters will need to be written as C<%%>, just like with
#pod C<sprintf>.
#pod
#pod =head3 @opt_spec
#pod
#pod The C<@opt_spec> part of the args to C<describe_options> is used to configure
#pod option parsing and to produce the usage message.  Each entry in the list is an
#pod arrayref describing one option, like this:
#pod
#pod   @opt_spec = (
#pod     [ "verbose|V" => "be noisy"       ],
#pod     [ "logfile=s" => "file to log to" ],
#pod   );
#pod
#pod The first value in the arrayref is a Getopt::Long-style option specification.
#pod In brief, they work like this:  each one is a pipe-delimited list of names,
#pod optionally followed by a type declaration.  Type declarations are '=x' or ':x',
#pod where C<=> means a value is required and C<:> means it is optional.  I<x> may
#pod be 's' to indicate a string is required, 'i' for an integer, or 'f' for a
#pod number with a fractional part.  The type spec may end in C<@> to indicate that
#pod the option may appear multiple times.
#pod
#pod For more information on how these work, see the L<Getopt::Long> documentation.
#pod
#pod The first name given should be the canonical name, as it will be used as the
#pod accessor method on the C<$opt> object.  Dashes in the name will be converted to
#pod underscores, and all letters will be lowercased.  For this reason, all options
#pod should generally have a long-form name.
#pod
#pod The second value in the arrayref is a description of the option, for use in the
#pod usage message.
#pod
#pod =head4 Special Option Specifications
#pod
#pod If the option specification (arrayref) is empty, it will have no effect other
#pod than causing a blank line to appear in the usage message.
#pod
#pod If the option specification contains only one element, it will be printed in
#pod the usage message with no other effect.
#pod
#pod If the option specification contains a third element, it adds extra constraints
#pod or modifiers to the interpretation and validation of the value.  These are the
#pod keys that may be present in that hashref, and how they behave:
#pod
#pod =over 4
#pod
#pod =item implies
#pod
#pod   implies => 'bar'
#pod   implies => [qw(foo bar)]
#pod   implies => { foo => 1, bar => 2 }
#pod
#pod If option I<A> has an "implies" entry, then if I<A> is given, other options
#pod will be enabled.  The value may be a single option to set, an arrayref of
#pod options to set, or a hashref of options to set to specific values.
#pod
#pod =item required
#pod
#pod   required => 1
#pod
#pod If an option is required, failure to provide the option will result in
#pod C<describe_options> printing the usage message and exiting.
#pod
#pod =item hidden
#pod
#pod   hidden => 1
#pod
#pod This option will not show up in the usage text.
#pod
#pod You can achieve the same behavior by using the string "hidden" for the option's
#pod description.
#pod
#pod =item one_of
#pod
#pod   one_of => \@subopt_specs
#pod
#pod This is useful for a group of options that are related.  Each option
#pod spec is added to the list for normal parsing and validation.
#pod
#pod Your option name will end up with a value of the name of the
#pod option that was chosen.  For example, given the following spec:
#pod
#pod   [ "mode" => hidden => { one_of => [
#pod     [ "get|g"  => "get the value" ],
#pod     [ "set|s"  => "set the value" ],
#pod     [ "delete" => "delete it" ],
#pod   ] } ],
#pod
#pod No usage text for 'mode' will be displayed, but text for get, set, and delete
#pod will be displayed.
#pod
#pod If more than one of get, set, or delete is given, an error will be thrown.
#pod
#pod So, given the C<@opt_spec> above, and an C<@ARGV> of C<('--get')>, the
#pod following would be true:
#pod
#pod   $opt->get == 1;
#pod
#pod   $opt->mode eq 'get';
#pod
#pod B<Note>: C<get> would not be set if C<mode> defaulted to 'get' and no arguments
#pod were passed in.
#pod
#pod Even though the option sub-specs for C<one_of> are meant to be 'first
#pod class' specs, some options don't make sense with them, e.g. C<required>.
#pod
#pod As a further shorthand, you may specify C<one_of> options using this form:
#pod
#pod   [ mode => \@option_specs, \%constraints ]
#pod
#pod
#pod =item shortcircuit
#pod
#pod   shortcircuit => 1
#pod
#pod If this option is present no other options will be returned.  Other
#pod options present will be checked for proper types, but I<not> for
#pod constraints.  This provides a way of specifying C<--help> style options.
#pod
#pod =item Params::Validate
#pod
#pod In addition, any constraint understood by Params::Validate may be used.
#pod
#pod For example, to accept positive integers:
#pod
#pod   [ 'max-iterations=i', "maximum number of iterations",
#pod     { callbacks => { positive => sub { shift() > 0 } } } ],
#pod
#pod (Internally, all constraints are translated into Params::Validate options or
#pod callbacks.)
#pod
#pod =back
#pod
#pod =head3 %arg
#pod
#pod The C<%arg> to C<describe_options> is optional.  If the last parameter is a
#pod hashref, it contains extra arguments to modify the way C<describe_options>
#pod works.  Valid arguments are:
#pod
#pod   getopt_conf   - an arrayref of strings, passed to Getopt::Long::Configure
#pod   show_defaults - a boolean which controls whether an option's default
#pod                   value (if applicable) is shown as part of the usage message
#pod                   (for backward compatibility this defaults to false)
#pod
#pod =head2 prog_name
#pod
#pod This routine, exported on demand, returns the basename of C<$0>, grabbed at
#pod compile-time.  You can override this guess by calling C<prog_name($string)>
#pod yourself.
#pod
#pod =head1 OTHER EXPORTS
#pod
#pod =head2 C<-types>
#pod
#pod Any of the Params::Validate type constants (C<SCALAR>, etc.) can be imported as
#pod well.  You can get all of them at once by importing C<-types>.
#pod
#pod =head2 C<-all>
#pod
#pod This import group will import C<-type>, C<describe_options>, and C<prog_name>.
#pod
#pod =cut

my $prog_name;
sub prog_name { @_ ? ($prog_name = shift) : $prog_name }

BEGIN {
  # grab this before someone decides to change it
  prog_name(File::Basename::basename($0));
}

use Sub::Exporter::Util ();
use Sub::Exporter 0.972 -setup => {
  exports => [
    describe_options => \'_build_describe_options',
    q(prog_name),
    @{ $Params::Validate::EXPORT_TAGS{types} }
  ],
  groups  => [
    default => [ qw(describe_options) ],
    types   => $Params::Validate::EXPORT_TAGS{types},
  ],
};

my %CONSTRAINT = (
  implies  => \&_mk_implies,
  required => { optional => 0 },
  only_one => \&_mk_only_one,
);

our $MungeOptions = 1;

sub _nohidden {
  return grep { ! $_->{constraint}->{hidden} } @_;
}

sub _expand {
  my @expanded;

  for my $opt (@_) {
    push @expanded, {
      spec       => $opt->[0] || '',
      desc       => @$opt > 1 ? $opt->[1] : 'spacer',
      constraint => $opt->[2] || {},

      # if @$_ is 0 then we got [], a spacer
      name       => @$opt ? _munge((split /[:=|!+]/, $opt->[0] || '')[0]) : '',
    };
  }

  return @expanded;
}

my %HIDDEN = (
  hidden => 1,
);

my $SPEC_RE = qr{(?:[:=][0-9\w\+]+[%@]?(\{[0-9]*,[0-9]*\})?|[!+])$};
sub _strip_assignment {
  my ($self, $str) = @_;

  (my $copy = $str) =~ s{$SPEC_RE}{};

  if (wantarray) {
      my $len = length $copy;
      my $assignment = substr $str, $len;
      if (!defined($assignment)) {
          $assignment = '';
      }
      return ($copy, $assignment);
  }
  return $copy;
}

# This is here only to deal with people who were calling this fully-qualified
# without importing.  Sucks to them!  -- rjbs, 2009-08-21
sub describe_options {
  my $sub = __PACKAGE__->_build_describe_options(describe_options => {} => {});
  $sub->(@_);
}

sub usage_class { 'Getopt::Long::Descriptive::Usage' }

sub _build_describe_options {
  my ($class) = @_;

  sub {
    my $format = shift;
    my $arg    = (ref $_[-1] and ref $_[-1] eq 'HASH') ? pop @_ : {};
    my @opts;

    my %parent_of;

    # special casing
    # wish we had real loop objects
    my %method_map;
    for my $opt (_expand(@_)) {
      $method_map{ $opt->{name} } = undef unless $opt->{desc} eq 'spacer';

      if (ref($opt->{desc}) eq 'ARRAY') {
        $opt->{constraint}->{one_of} = delete $opt->{desc};
        $opt->{desc} = 'hidden';
      }

      if ($HIDDEN{$opt->{desc}}) {
        $opt->{constraint}->{hidden}++;
      }

      if ($opt->{constraint}->{one_of}) {
        for my $one_opt (_expand(
          @{delete $opt->{constraint}->{one_of}}
        )) {
          $parent_of{$one_opt->{name}} = $opt->{name};
          $one_opt->{constraint}->{implies}
            ->{$opt->{name}} = $one_opt->{name};
          for my $wipe (qw(required default)) {
            if ($one_opt->{constraint}->{$wipe}) {
              carp "'$wipe' constraint does not make sense in sub-option";
              delete $one_opt->{constraint}->{$wipe};
            }
          }
          $one_opt->{constraint}->{one_of} = $opt->{name};
          push @opts, $one_opt;
        }
      }

      if ($opt->{constraint}{shortcircuit}
        && exists $opt->{constraint}{default}
      ) {
        carp('option "' . $opt->{name} . q[": 'default' does not make sense for shortcircuit options]);
      }

      push @opts, $opt;
    }

    my @go_conf = @{ $arg->{getopt_conf} || $arg->{getopt} || [] };
    if ($arg->{getopt}) {
      warn "describe_options: 'getopt' is deprecated, please use 'getopt_conf' instead\n";
    }

    push @go_conf, "bundling" unless grep { /bundling/i } @go_conf;
    push @go_conf, "no_auto_help"  unless grep { /no_auto_help/i } @go_conf;
    push @go_conf, "no_ignore_case"
      unless grep { /no_ignore_case/i } @go_conf;

    # not entirely sure that all of this (until the Usage->new) shouldn't be
    # moved into Usage -- rjbs, 2009-08-19

    # all specs including hidden
    my @getopt_specs =
      map  { $_->{spec} }
      grep { $_->{desc} ne 'spacer' }
      @opts;

    my @specs =
      map  { $_->{spec} }
      grep { $_->{desc} ne 'spacer' }
      _nohidden(@opts);

    my $short = join q{},
      sort  { lc $a cmp lc $b or $a cmp $b }
      grep  { /^.$/ }
      map   { split /\|/ }
      map   { scalar __PACKAGE__->_strip_assignment($_) }
      @specs;

    my $long = grep /\b[^|]{2,}/, @specs;

    my %replace = (
      "%" => "%",
      "c" => prog_name,
      "o" => join(q{ },
        ($short ? "[-$short]" : ()),
        ($long  ? "[long options...]" : ())
      ),
    );

    (my $str = $format) =~ s<%(.)><
      defined $replace{$1}
      ? $replace{$1}
      : Carp::croak("unknown sequence %$1 in first argument to describe_options")
    >ge;

    $str =~ s/[\x20\t]{2,}/ /g;

    my $usage = $class->usage_class->new({
      options       => [ _nohidden(@opts) ],
      leader_text   => $str,
      show_defaults => $arg->{show_defaults},
    });

    Getopt::Long::Configure(@go_conf);

    my %return;
    $usage->die unless GetOptions(\%return, grep { length } @getopt_specs);
    my @given_keys = keys %return;

    for my $opt (keys %return) {
      my $newopt = _munge($opt);
      next if $newopt eq $opt;
      $return{$newopt} = delete $return{$opt};
    }

    # ensure that shortcircuit options are handled first
    for my $copt (
      sort {     ($b->{constraint}{shortcircuit} || 0)
             <=> ($a->{constraint}{shortcircuit} || 0)
           } grep { $_->{constraint} } @opts
    ) {
      delete $copt->{constraint}->{hidden};
      my $is_shortcircuit = delete $copt->{constraint}{shortcircuit};
      my $name = $copt->{name};
      my $new  = _validate_with(
        name   => $name,
        params => \%return,
        spec   => $copt->{constraint},
        opts   => \@opts,
        usage  => $usage,
        given_keys => \@given_keys,
        parent_of  => \%parent_of,
      );
      next unless (defined($new) || exists($return{$name}));
      $return{$name} = $new;

      if ($is_shortcircuit) {
        %return = ($name => $return{$name});
        last;
      }
    }

    my $opt_obj = Getopt::Long::Descriptive::Opts->___new_opt_obj({
      values => { %method_map, %return },
      given  => { map {; $_ => 1 } @given_keys },
    });

    return($opt_obj, $usage);
  }
}

sub _munge {
  my ($opt) = @_;
  return $opt unless $MungeOptions;
  $opt = lc($opt);
  $opt =~ tr/-/_/;
  return $opt;
}

sub _validate_with {
  my (%arg) = validate(@_, {
    name   => 1,
    params => 1,
    spec   => 1,
    opts   => 1,
    usage  => 1,
    given_keys => 1,
    parent_of  => 1,
  });

  my $spec = $arg{spec};
  my %pvspec;
  for my $ct (keys %{$spec}) {
    if ($CONSTRAINT{$ct} and ref $CONSTRAINT{$ct} eq 'CODE') {
      $pvspec{callbacks} ||= {};
      $pvspec{callbacks} = {
        %{$pvspec{callbacks}},
        $CONSTRAINT{$ct}->(
          $arg{name},
          $spec->{$ct},
          $arg{params},
          $arg{opts},
        ),
      };
    } else {
      %pvspec = (
        %pvspec,
        $CONSTRAINT{$ct} ? %{$CONSTRAINT{$ct}} : ($ct => $spec->{$ct}),
      );
    }
  }

  $pvspec{optional} = 1 unless exists $pvspec{optional};

  # we need to implement 'default' by ourselves sometimes
  # because otherwise the implies won't be checked/executed
  # XXX this should be more generic -- we'll probably want
  # other callbacks to always run, too
  if (!defined($arg{params}{$arg{name}})
        && $pvspec{default}
          && $spec->{implies}) {

    $arg{params}{$arg{name}} = delete $pvspec{default};
  }

  my %p;
  my $ok = eval {
    %p = validate_with(
      params => [
        %{$arg{params}},
        '-given_keys', $arg{given_keys},
        '-parent_of',  $arg{parent_of},
      ],
      spec   => { $arg{name} => \%pvspec },
      allow_extra => 1,
      on_fail     => sub {
        my $fail_msg = shift;
        Getopt::Long::Descriptive::_PV_Error->throw($fail_msg);
      },
    );
    1;
  };

  if (! $ok) {
    my $error = $@;
    if (
      Scalar::Util::blessed($error)
      && $error->isa('Getopt::Long::Descriptive::_PV_Error')
    ) {
      $arg{usage}->die({ pre_text => $error->error . "\n" });
    }

    die $@;
  }

  return $p{$arg{name}};
}

# scalar:   single option = true
# arrayref: multiple options = true
# hashref:  single/multiple options = given values
sub _norm_imply {
  my ($what) = @_;

  return { $what => 1 } unless my $ref = ref $what;

  return $what                      if $ref eq 'HASH';
  return { map { $_ => 1 } @$what } if $ref eq 'ARRAY';

  die "can't imply: $what";
}

sub _mk_implies {
  my $name = shift;
  my $what = _norm_imply(shift);
  my $param = shift;
  my $opts  = shift;

  for my $implied (keys %$what) {
    die("option specification for $name implies nonexistent option $implied\n")
      unless first { $_->{name} eq $implied } @$opts
  }

  my $whatstr = join(q{, }, map { "$_=$what->{$_}" } keys %$what);

  return "$name implies $whatstr" => sub {
    my ($pv_val, $rest) = @_;

    # negatable options will be 0 here, which is ok.
    return 1 unless defined $pv_val;

    while (my ($key, $val) = each %$what) {
      # Really, this should be called "-implies" and should include all implies
      # relationships, but they'll have to get handled by setting conflicts.
      my $parent   = $rest->{'-parent_of'}{$name};
      my @siblings = $parent
                   ? (grep {; defined $rest->{'-parent_of'}{$_}
                              && $rest->{'-parent_of'}{$_} eq $parent }
                      @{ $rest->{'-given_keys'} })
                   : ();

      if (@siblings > 1) {
        die "these options conflict; each wants to set the $parent: @siblings\n";
      }

      if (  exists $param->{$key}
        and $param->{$key} ne $val
        and grep {; $_ eq $key } @{ $rest->{'-given_keys'} }
      ) {
        die(
          "option specification for $name implies that $key should be "
          . "set to '$val', but it is '$param->{$key}' already\n"
        );
      }
      $param->{$key} = $val;
    }

    return 1;
  };
}

sub _mk_only_one {
  die "unimplemented";
}

{
  package
    Getopt::Long::Descriptive::_PV_Error;
  sub error { $_[0]->{error} }
  sub throw {
    my ($class, $error_msg) = @_;
    my $self = { error => $error_msg };
    bless $self, $class;
    die $self;
  }
}

#pod =head1 CUSTOMIZING
#pod
#pod Getopt::Long::Descriptive uses L<Sub::Exporter|Sub::Exporter> to build and
#pod export the C<describe_options> routine.  By writing a new class that extends
#pod Getopt::Long::Descriptive, the behavior of the constructed C<describe_options>
#pod routine can be changed.
#pod
#pod The following methods can be overridden:
#pod
#pod =head2 usage_class
#pod
#pod   my $class = Getopt::Long::Descriptive->usage_class;
#pod
#pod This returns the class to be used for constructing a Usage object, and defaults
#pod to Getopt::Long::Descriptive::Usage.
#pod
#pod =head1 SEE ALSO
#pod
#pod =for :list
#pod * L<Getopt::Long>
#pod * L<Params::Validate>
#pod
#pod =cut

1; # End of Getopt::Long::Descriptive

__END__

=pod

=encoding UTF-8

=head1 NAME

Getopt::Long::Descriptive - Getopt::Long, but simpler and more powerful

=head1 VERSION

version 0.102

=head1 SYNOPSIS

  use Getopt::Long::Descriptive;

  my ($opt, $usage) = describe_options(
    'my-program %o <some-arg>',
    [ 'server|s=s', "the server to connect to", { required => 1  } ],
    [ 'port|p=i',   "the port to connect to",   { default  => 79 } ],
    [],
    [ 'verbose|v',  "print extra stuff"            ],
    [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
  );

  print($usage->text), exit if $opt->help;

  Client->connect( $opt->server, $opt->port );

  print "Connected!\n" if $opt->verbose;

...and running C<my-program --help> will produce:

  my-program [-psv] [long options...] <some-arg>
    -s --server     the server to connect to
    -p --port       the port to connect to

    -v --verbose    print extra stuff
    --help          print usage message and exit

=head1 DESCRIPTION

Getopt::Long::Descriptive is yet another Getopt library.  It's built atop
Getopt::Long, and gets a lot of its features, but tries to avoid making you
think about its huge array of options.

It also provides usage (help) messages, data validation, and a few other useful
features.

=head1 FUNCTIONS

Getopt::Long::Descriptive only exports one routine by default:
C<describe_options>.  All GLD's exports are exported by L<Sub::Exporter>.

=head2 describe_options

  my ($opt, $usage) = describe_options($usage_desc, @opt_spec, \%arg);

This routine inspects C<@ARGV> for options that match the supplied spec. If all
the options are valid then it returns the options given and an object for
generating usage messages; if not then it dies with an explanation of what was
wrong and a usage message.

The C<$opt> object will be a dynamically-generated subclass of
L<Getopt::Long::Descriptive::Opts>.  In brief, each of the options in
C<@opt_spec> becomes an accessor method on the object, using the first-given
name, with dashes converted to underscores.  For more information, see the
documentation for the Opts class.

The C<$usage> object will be a L<Getopt::Long::Descriptive::Usage> object,
which provides a C<text> method to get the text of the usage message and C<die>
to die with it.  For more methods and options, consults the documentation for
the Usage class.

=head3 $usage_desc

The C<$usage_desc> parameter to C<describe_options> is a C<sprintf>-like string
that is used in generating the first line of the usage message.  It's a
one-line summary of how the command is to be invoked.  A typical usage
description might be:

  $usage_desc = "%c %o <source> <desc>";

C<%c> will be replaced with what Getopt::Long::Descriptive thinks is the
program name (it's computed from C<$0>, see L</prog_name>).

C<%o> will be replaced with a list of the short options, as well as the text
"[long options...]" if any have been defined.

The rest of the usage description can be used to summarize what arguments are
expected to follow the program's options, and is entirely free-form.

Literal C<%> characters will need to be written as C<%%>, just like with
C<sprintf>.

=head3 @opt_spec

The C<@opt_spec> part of the args to C<describe_options> is used to configure
option parsing and to produce the usage message.  Each entry in the list is an
arrayref describing one option, like this:

  @opt_spec = (
    [ "verbose|V" => "be noisy"       ],
    [ "logfile=s" => "file to log to" ],
  );

The first value in the arrayref is a Getopt::Long-style option specification.
In brief, they work like this:  each one is a pipe-delimited list of names,
optionally followed by a type declaration.  Type declarations are '=x' or ':x',
where C<=> means a value is required and C<:> means it is optional.  I<x> may
be 's' to indicate a string is required, 'i' for an integer, or 'f' for a
number with a fractional part.  The type spec may end in C<@> to indicate that
the option may appear multiple times.

For more information on how these work, see the L<Getopt::Long> documentation.

The first name given should be the canonical name, as it will be used as the
accessor method on the C<$opt> object.  Dashes in the name will be converted to
underscores, and all letters will be lowercased.  For this reason, all options
should generally have a long-form name.

The second value in the arrayref is a description of the option, for use in the
usage message.

=head4 Special Option Specifications

If the option specification (arrayref) is empty, it will have no effect other
than causing a blank line to appear in the usage message.

If the option specification contains only one element, it will be printed in
the usage message with no other effect.

If the option specification contains a third element, it adds extra constraints
or modifiers to the interpretation and validation of the value.  These are the
keys that may be present in that hashref, and how they behave:

=over 4

=item implies

  implies => 'bar'
  implies => [qw(foo bar)]
  implies => { foo => 1, bar => 2 }

If option I<A> has an "implies" entry, then if I<A> is given, other options
will be enabled.  The value may be a single option to set, an arrayref of
options to set, or a hashref of options to set to specific values.

=item required

  required => 1

If an option is required, failure to provide the option will result in
C<describe_options> printing the usage message and exiting.

=item hidden

  hidden => 1

This option will not show up in the usage text.

You can achieve the same behavior by using the string "hidden" for the option's
description.

=item one_of

  one_of => \@subopt_specs

This is useful for a group of options that are related.  Each option
spec is added to the list for normal parsing and validation.

Your option name will end up with a value of the name of the
option that was chosen.  For example, given the following spec:

  [ "mode" => hidden => { one_of => [
    [ "get|g"  => "get the value" ],
    [ "set|s"  => "set the value" ],
    [ "delete" => "delete it" ],
  ] } ],

No usage text for 'mode' will be displayed, but text for get, set, and delete
will be displayed.

If more than one of get, set, or delete is given, an error will be thrown.

So, given the C<@opt_spec> above, and an C<@ARGV> of C<('--get')>, the
following would be true:

  $opt->get == 1;

  $opt->mode eq 'get';

B<Note>: C<get> would not be set if C<mode> defaulted to 'get' and no arguments
were passed in.

Even though the option sub-specs for C<one_of> are meant to be 'first
class' specs, some options don't make sense with them, e.g. C<required>.

As a further shorthand, you may specify C<one_of> options using this form:

  [ mode => \@option_specs, \%constraints ]

=item shortcircuit

  shortcircuit => 1

If this option is present no other options will be returned.  Other
options present will be checked for proper types, but I<not> for
constraints.  This provides a way of specifying C<--help> style options.

=item Params::Validate

In addition, any constraint understood by Params::Validate may be used.

For example, to accept positive integers:

  [ 'max-iterations=i', "maximum number of iterations",
    { callbacks => { positive => sub { shift() > 0 } } } ],

(Internally, all constraints are translated into Params::Validate options or
callbacks.)

=back

=head3 %arg

The C<%arg> to C<describe_options> is optional.  If the last parameter is a
hashref, it contains extra arguments to modify the way C<describe_options>
works.  Valid arguments are:

  getopt_conf   - an arrayref of strings, passed to Getopt::Long::Configure
  show_defaults - a boolean which controls whether an option's default
                  value (if applicable) is shown as part of the usage message
                  (for backward compatibility this defaults to false)

=head2 prog_name

This routine, exported on demand, returns the basename of C<$0>, grabbed at
compile-time.  You can override this guess by calling C<prog_name($string)>
yourself.

=head1 OTHER EXPORTS

=head2 C<-types>

Any of the Params::Validate type constants (C<SCALAR>, etc.) can be imported as
well.  You can get all of them at once by importing C<-types>.

=head2 C<-all>

This import group will import C<-type>, C<describe_options>, and C<prog_name>.

=head1 CUSTOMIZING

Getopt::Long::Descriptive uses L<Sub::Exporter|Sub::Exporter> to build and
export the C<describe_options> routine.  By writing a new class that extends
Getopt::Long::Descriptive, the behavior of the constructed C<describe_options>
routine can be changed.

The following methods can be overridden:

=head2 usage_class

  my $class = Getopt::Long::Descriptive->usage_class;

This returns the class to be used for constructing a Usage object, and defaults
to Getopt::Long::Descriptive::Usage.

=head1 SEE ALSO

=over 4

=item *

L<Getopt::Long>

=item *

L<Params::Validate>

=back

=head1 AUTHORS

=over 4

=item *

Hans Dieter Pearcey <hdp@cpan.org>

=item *

Ricardo Signes <rjbs@cpan.org>

=back

=head1 CONTRIBUTORS

=for stopwords Arthur Axel 'fREW' Schmidt Dave Rolsky Diab Jerius Hans Dieter Pearcey Harley Pig hdp@cpan.org Karen Etheridge Niels Thykier Olaf Alders Roman Hubacek Smylers Thomas Neumann zhouzhen1

=over 4

=item *

Arthur Axel 'fREW' Schmidt <frioux@gmail.com>

=item *

Dave Rolsky <autarch@urth.org>

=item *

Diab Jerius <djerius@cfa.harvard.edu>

=item *

Hans Dieter Pearcey <hdp@pobox.com>

=item *

Hans Dieter Pearcey <hdp@weftsoar.net>

=item *

Harley Pig <harleypig@gmail.com>

=item *

hdp@cpan.org <hdp@cpan.org@fc0e91e4-031c-0410-8307-be39b06d7656>

=item *

Karen Etheridge <ether@cpan.org>

=item *

Niels Thykier <niels@thykier.net>

=item *

Olaf Alders <olaf@wundersolutions.com>

=item *

Roman Hubacek <roman.hubacek@centrum.cz>

=item *

Smylers <SMYLERS@cpan.fsck.com>

=item *

Thomas Neumann <blacky+perl@fluffbunny.de>

=item *

zhouzhen1 <zhouzhen1@gmail.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2005 by Hans Dieter Pearcey.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
