package Test::Mojo::IRC;

=head1 NAME

Test::Mojo::IRC - Module for testing Mojo::IRC

=head1 SYNOPSIS

  use Test::Mojo::IRC -basic;

  my $t      = Test::Mojo::IRC->new;
  my $server = $t->start_server;
  my $irc    = Mojo::IRC->new(server => $server);

  # simulate server/client communication
  $t->run(
    [
      # Send t/data/welcome when client sends "NICK"
      # The file contains the MOTD text
      qr{\bNICK\b} => \ "t/data/welcome",
    ],
    sub {
      my $err;
      my $motd = 0;
      $t->on($irc, irc_rpl_motd => sub { $motd++ });
      $t->on($irc, irc_rpl_endofmotd => sub { Mojo::IOLoop->stop; }); # need to manually stop the IOLoop
      $irc->connect(sub { $err = $_[1]; });
      Mojo::IOLoop->start; # need to manually start the IOLoop
      is $err, "", "connected";
      is $motd, 19, "message of the day has of 15 lines";
    },
  );

  done_testing;

=head1 DESCRIPTION

L<Test::Mojo::IRC> is a module for making it easier to test L<Mojo::IRC>
applications.

=head1 ENVIRONMENT VARIABLES

=head2 TEST_MOJO_IRC_SERVER

C<TEST_MOJO_IRC_SERVER> can be set to point to a live server. If the variable
is set, L</start_server> will simply return L<TEST_MOJO_IRC_SERVER> instead
of setting up a server.

=cut

use Mojo::Base -base;
use Mojo::IOLoop::Server;
use Mojo::IRC;
use Mojo::Util;

$ENV{TEST_MOJO_IRC_SERVER_TIMEOUT} ||= $ENV{TEST_MOJO_IRC_SERVER} ? 10 : 4;

=head1 ATTRIBUTES

=head2 welcome_message

  $str = $self->welcome_message;
  $self = $self->welcome_message($str);

Holds a message which will be sent to the client on connect.

=cut

has welcome_message => <<'HERE';
:hybrid8.local NOTICE AUTH :*** Looking up your hostname...
:hybrid8.local NOTICE AUTH :*** Checking Ident
:hybrid8.local NOTICE AUTH :*** Found your hostname
:hybrid8.local NOTICE AUTH :*** No Ident response
HERE

=head1 METHODS

=head2 on

  $self->on($irc, $event, $cb);

Will attach events to the L<$irc|Mojo::IRC> object which is removed
after L</run> has completed. See L</SYNOPSIS> for example code.

=cut

sub on {
  my ($self, $irc, $event, $cb) = @_;
  push @{$self->{subscriptions}}, $irc, $event, $irc->on($event => $cb);
  $self;
}

=head2 run

  $self->run($reply_on, $cb);

Used to simulate communication between IRC server and client. The way this
works is that the C<$cb> will initiate L<connect|Mojo::IRC/connect> or
L<write|Mojo::IRC/write> to the server and the server will then respond
with the data from either L</welcome_message> or C<$reply_on> on these
events.

C<$reply_on> is an array-ref of regex/buffer pairs. Each time a message
from the client match the first regex in the C<$reply_on> array the
buffer will be sent back to the client and the regex/buffer will be removed.
This means that the order of the pairs are important. The buffer can be either
a scalar ref (path to file) or a plain scalar (simple buffer).

Note that starting and stopping the L<IOLoop|Mojo::IOLoop> is up to you, but
there is also a master timeout which will stop the IOLoop if running for too
long.

See L</SYNOPSIS> for example.

=cut

sub run {
  my ($self, $reply_on, $cb) = @_;
  my $guard = Mojo::IOLoop->timer($ENV{TEST_MOJO_IRC_SERVER_TIMEOUT}, sub { Mojo::IOLoop->stop });
  my @subscriptions;

  local $self->{from_client}   = '';
  local $self->{reply_on}      = $reply_on;
  local $self->{server_buf}    = '';
  local $self->{subscriptions} = \@subscriptions;

  $self->$cb;
  Mojo::IOLoop->remove($guard);

  while (@subscriptions) {
    my ($irc, $event, $cb) = splice @subscriptions, 0, 3, ();
    $irc->unsubscribe($event => $cb);
  }

  $self;
}

=head2 start_server

  $server = $self->start_server;

Will start a test server and return the "host:port" which it listens to.

=cut

sub start_server {
  my $self = shift;

  return $self->{server} if $self->{server};
  return $ENV{TEST_MOJO_IRC_SERVER} if $ENV{TEST_MOJO_IRC_SERVER};

  my $port = Mojo::IOLoop::Server->generate_port;
  my $write;

  $write = sub {
    return unless length $self->{server_buf};
    return shift->write(substr($self->{server_buf}, 0, int(10 + rand 20), ''), sub { shift->$write });
  };

  $self->{server_id} = Mojo::IOLoop->server(
    {address => '127.0.0.1', port => $port},
    sub {
      my ($ioloop, $stream) = @_;

      $stream->on(
        read => sub {
          my ($stream, $buf) = @_;
          $self->{from_client} .= $buf;

          while ($buf =~ /\r\n/g) {
            last unless @{$self->{reply_on}};
            last unless $self->{from_client} =~ $self->{reply_on}[0];
            $self->_concat_server_buf($self->{reply_on}[1]);
            splice @{$self->{reply_on}}, 0, 2, ();
          }

          $stream->$write;
        }
      );

      $self->_concat_server_buf($self->welcome_message);
      $stream->$write;
    }
  );

  $self->{server} = "127.0.0.1:$port";
}

sub _concat_server_buf {
  my ($self, $buf) = @_;

  $buf = Mojo::Util::slurp(File::Spec->catfile(split '/', $$buf)) if ref $buf;
  $buf =~ s/\r?\n/\r\n/g;
  $self->{server_buf} .= $buf;
}

=head2 import

  use Test::Mojo::IRC -basic;

Loading this module with "-basic" will import L<strict>, L<warnings>, L<utf8>,
L<Test::More> and 5.10 features into the caller namespace.

=cut

sub import {
  my $class  = shift;
  my $arg    = shift // '';
  my $caller = caller;

  return unless $arg eq '-basic';
  $_->import for qw(strict warnings utf8);
  feature->import(':5.10');
  eval "package $caller; use Test::More; 1" or die $@;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
