use strict;
use warnings;
package Test::Deep::Collect;
# ABSTRACT: collect data while testing it

use List::Util ();

use Sub::Exporter -setup => {
  groups  => { default => [ qw(collector) ] },
  exports => [ qw(collector) ],
};

sub collector {
  return Test::Deep::Collect::Collector->new;
}

{
  package Test::Deep::Collect::Collector;
  sub new {
    bless { slots => {} } => $_[0]
  }

  # TODO: allow another argument storing whether to use num/str comparison?
  sub unique { Test::Deep::Collect::UniqueCmp->new(@_[0,1]) }
  sub uniq   { Test::Deep::Collect::UniqueCmp->new(@_[0,1]) }
  sub same   { Test::Deep::Collect::SameCmp->new(@_[0,1])   }
  sub save   { Test::Deep::Collect::SaveCmp->new(@_[0,1])   }

  sub single_value {
    my ($self, $slot) = @_;
    my @values = @{ $self->{slots}{$slot} || [] };

    Carp::croak("single_value called, but no value present for slot $slot")
      unless @values;

    Carp::croak("single_value called, but multiple values present for slot $slot")
      if @values > 1;

    return $values[0];
  }

  sub values {
    my ($self, $slot) = @_;
    return @{ $self->{slots}{$slot} || [] };
  }

  sub unique_values {
    my ($self, $slot) = @_;
    return List::Util::uniq(@{ $self->{slots}{$slot} });
  }
}

{
  package Test::Deep::Collect::_Cmp;
  use Test::Deep::Cmp; # remember: its ->import sets our @ISA

  sub init {
    $_[0]{collector} = $_[1];
    $_[0]{slot}      = $_[2];
  }

  sub _slotref {
    return $_[0]{collector}{slots}{ $_[0]{slot} } ||= [];
  }

  for my $method (qw(unique uniq save same)) {
    my $sub = sub {
      my $self = shift;
      my $cmp = $self->{collector}->$method(@_);
      return $self->make_all($cmp);
    };

    no strict 'refs';
    *$method = $sub;
  }
}

{
  package Test::Deep::Collect::UniqueCmp;
  our @ISA = qw(Test::Deep::Collect::_Cmp);

  sub descend {
    my ($self, $got) = @_;
    my $col  = $self->{collector};
    my $slot = $self->{slot};

    my $sref = $self->_slotref;
    my $ok   = 1;

    if (@$sref) {
      $ok = defined $got ? ( ! grep { defined $_ && $_ eq $got } @$sref)
                         : ( ! grep { ! defined } @$sref);
    }

    push @$sref, $got;
    return $ok;
  }

  sub diag_message {
    my ($self, $where) = @_;
    return "$where repeats previously seen value for $self->{slot}";
  }

  sub renderExp {
    my ($self) = @_;
    my $seen = $self->_slotref;
    return "anything other than: @$seen[ 0 .. $#$seen - 1 ]";
  }
}

{
  package Test::Deep::Collect::SameCmp;
  our @ISA = qw(Test::Deep::Collect::_Cmp);

  sub descend {
    my ($self, $got) = @_;
    my $col  = $self->{collector};
    my $slot = $self->{slot};

    my $sref = $self->_slotref;
    my $ok   = 1;

    if (@$sref) {
      $ok = defined $got ? (defined $sref->[0] && $sref->[0] eq $got)
                         : (! defined $sref->[0]);
    }

    push @$sref, $got;
    return $ok;
  }

  sub diag_message {
    my ($self, $where) = @_;
    return "$where differs from initial value for $self->{slot}";
  }

  sub renderExp {
    my ($self) = @_;
    return $self->_slotref->[0];
  }
}

{
  package Test::Deep::Collect::SaveCmp;
  our @ISA = qw(Test::Deep::Collect::_Cmp);

  sub descend {
    my ($self, $got) = @_;
    my $col  = $self->{collector};
    my $slot = $self->{slot};

    my $sref = $self->_slotref;
    push @{ $self->_slotref }, $got;
    return 1;
  }
}

1;
