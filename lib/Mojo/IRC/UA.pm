package Mojo::IRC::UA;

=head1 NAME

Mojo::IRC::UA - IRC Client with sugar on top

=head1 SYNOPSIS

  use Mojo::IRC::UA;
  my $irc = Mojo::IRC::UA->new;

=head1 DESCRIPTION

L<Mojo::IRC::UA> is a module which extends L<Mojo::IRC> with methods
that can track changes in state on the IRC server.

This module is EXPERIMENTAL and can change without warning.

=cut

use Mojo::Base 'Mojo::IRC';
use List::Util 'all';

=head1 ATTRIBUTES

L<Mojo::IRC::UA> inherits all attributes from L<Mojo::IRC> and implements the
following new ones.

=head2 op_timeout

  $int = $self->op_timeout;
  $self = $self->op_timeout($int);

Max number of seconds to wait for a response from the IRC server.

=cut

has op_timeout => 10;

=head1 EVENTS

L<Mojo::IRC::UA> inherits all events from L<Mojo::IRC> and implements the
following new ones.

=head1 METHODS

L<Mojo::IRC::UA> inherits all methods from L<Mojo::IRC> and implements the
following new ones.

=cut

sub _write_and_wait {
  my ($self, $msg, $look_for, $handler) = @_;
  my ($tid, $timeout, @subscriptions);

  # This method will send a IRC command to the server and wait for a
  # corresponding IRC event is returned from the server. On such an
  # event, the $handler callback will be called, but only if the event
  # received match the rules set in $look_for.

  # @subscriptions keeps track for the "private" IRC event handlers
  # for this method call, so we won't mess up other calls to
  # _write_and_wait() at the same time.

  Scalar::Util::weaken($self);

  # We want a "master timeout" as well, in case the server never send
  # us any response.
  $tid = Mojo::IOLoop->timer(
    ($timeout = $self->op_timeout),
    sub {
      $self->unsubscribe(shift @subscriptions, shift @subscriptions) while @subscriptions;
      $self->$handler(err_timeout => "Response timeout after ${timeout}s.", {});
    }
  );

  # Set up which IRC events to look for
  for my $event (keys %$look_for) {
    my $needle = $look_for->{$event};
    push @subscriptions, $event, $self->on(
      $event => sub {
        my ($self, $msg) = @_;
        return unless all { +(/^\d/ ? $msg->{params}[$_] : $msg->{$_}) // '' eq $needle->{$_} } keys %$needle;
        Mojo::IOLoop->remove($tid);
        $self->unsubscribe(shift @subscriptions, shift @subscriptions) while @subscriptions;
        $self->$handler($event => '', $msg);
      }
    );
  }

  # Write the command to the IRC server and stop looking for events
  # if the write fails.
  $self->write(
    $msg->{raw_line},
    sub {
      return unless $_[1];    # no error
      Mojo::IOLoop->remove($tid);
      $self->unsubscribe(shift @subscriptions, shift @subscriptions) while @subscriptions;
      $self->$handler(err_write => $_[1], {});
    }
  );

  return $self;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
