package Mojo::IRC;

=head1 NAME

Mojo::IRC - IRC Client for the Mojo IOLoop

=head1 VERSION

0.16

=head1 SYNOPSIS

  my $irc = Mojo::IRC->new(
              nick => 'test123',
              user => 'my name',
              server => 'irc.perl.org:6667',
            );

  $irc->on(irc_join => sub {
    my($self, $message) = @_;
    warn "yay! i joined $message->{params}[0]";
  });

  $irc->on(irc_privmsg => sub {
    my($self, $message) = @_;
    say $message->{prefix}, " said: ", $message->{params}[1];
  });

  $irc->connect(sub {
    my($irc, $err) = @_;
    return warn $err if $err;
    $irc->write(join => '#mojo');
  });

  Mojo::IOLoop->start;

=head1 DESCRIPTION

L<Mojo::IRC> is a non-blocking IRC client using L<Mojo::IOLoop> from the
wonderful L<Mojolicious> framework.

If features IPv6 and TLS, with additional optional modules:
L<IO::Socket::IP> and L<IO::Socket::SSL>.

By default this module will only emit standard IRC events, but by
settings L</parser> to a custom object it will also emit CTCP events.
Example:

  my $irc = Mojo::IRC->new;
  $irc->parser(Parse::IRC->new(ctcp => 1);
  $irc->on(ctcp_action => sub {
    # ...
  });

It will also set up some default events: L</ctcp_ping>, L</ctcp_time>,
and L</ctcp_version>.

This class inherit from L<Mojo::EventEmitter>.

=head1 TESTING

Set L<MOJO_IRC_OFFLINE> to allow testing without a remote host. Example:

  BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
  use Mojo::Base -strict;
  use Mojo::IRC;
  use Test::More;

  my $irc = Mojo::IRC->new(nick => 'batman', server => 'test.com');
  $irc->parser(Parse::IRC->new(ctcp => 1));

  $irc->on(
    ctcp_avatar => sub {
      my($irc, $message) = @_;
      $irc->write(
        NOTICE => $message->{params}[0],
        $irc->ctcp(AVATAR => 'https://graph.facebook.com/jhthorsen/picture'),
      );
    }
  );

  $irc->from_irc_server(":abc-123 PRIVMSG batman :\x{1}AVATAR\x{1}\r\n");
  like $irc->{to_irc_server}, qr{NOTICE batman :\x{1}AVATAR https://graph.facebook.com/jhthorsen/picture\x{1}\r\n}, 'sent AVATAR';
  done_testing;

NOTE! C<from_irc_server()> is only available when C<MOJO_IRC_OFFLINE> is set.

=head1 EVENTS

=head2 close

Emitted once the connection to the server close.

=head2 error

Emitted once the stream emits an error.

=head2 err_event_name

Events that start with "err_" is emitted when there is an IRC response that
indicate an error. See L<Mojo::IRC::Events> for example events.

=head2 ctcp_event_name

Events that start with "ctcp_" is emitted if the L</parser> can understand
CTCP messages, and there is an CTCP response.

  $self->parser(Parse::IRC->new(ctcp => 1);

See L<Mojo::IRC::Events> for example events.

=head2 irc_error

This event is used to emit IRC errors. It is also possible for finer
granularity to listen for events such as C<err_nicknameinuse>.

NOTE: L</irc_error> events are emitted even if you listen to C<err_> events,
but they are always emitted I<after> the C<err_> event.

=head2 irc_event_name

Events that start with "irc_" is emit when there is a normal IRC response.
See L<Mojo::IRC::Events> for example events.

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::IOLoop;
use File::Basename 'dirname';
use File::Spec::Functions 'catfile';
use IRC::Utils   ();
use Parse::IRC   ();
use Scalar::Util ();
use Unicode::UTF8;
use constant DEBUG => $ENV{MOJO_IRC_DEBUG} ? 1 : 0;
use constant DEFAULT_CERT => $ENV{MOJO_IRC_CERT_FILE} || catfile dirname(__FILE__), 'mojo-irc-client.crt';
use constant DEFAULT_KEY  => $ENV{MOJO_IRC_KEY_FILE}  || catfile dirname(__FILE__), 'mojo-irc-client.key';
use constant OFFLINE => $ENV{MOJO_IRC_OFFLINE} ? 1 : 0;

our $VERSION = '0.16';

my %CTCP_QUOTE = ("\012" => 'n', "\015" => 'r', "\0" => '0', "\cP" => "\cP");

my @DEFAULT_EVENTS = qw(
  irc_ping irc_nick irc_notice irc_rpl_welcome err_nicknameinuse
  ctcp_ping ctcp_time ctcp_version
);

=head1 ATTRIBUTES

=head2 ioloop

Holds an instance of L<Mojo::IOLoop>.

=head2 name

The name of this IRC client. Defaults to "Mojo IRC".

=head2 nick

IRC nick name accessor.

=head2 parser

  $self = $self->parser($obj);
  $self = $self->parser(Parse::IRC->new(ctcp => 1));
  $obj = $self->parser;

Holds a L<Parse::IRC> object by default.

=head2 pass

Password for authentication

=head2 real_host

Will be set by L</irc_rpl_welcome>. Holds the actual hostname of the IRC
server that we are connected to.

=head2 server

Server name and optionally a port to connect to. Changing this while connected
to the IRC server will issue a reconnect.

=head2 tls

  $self->tls(undef) # disable (default)
  $self->tls({}) # enable

Default is "undef" which disable TLS. Setting this to an empty hash will
enable TLS and this module will load in default certs. It is also possible
to set custom cert/key:

  $self->tls({ cert => "/path/to/client.crt", key => ... })

This can be generated using

  # certtool --generate-privkey --outfile client.key
  # certtool --generate-self-signed --load-privkey client.key --outfile client.crt

=head2 user

IRC username.

=cut

has ioloop => sub { Mojo::IOLoop->singleton };
has name   => 'Mojo IRC';
has nick   => '';
has parser => sub { Parse::IRC->new; };
has pass   => '';
has real_host => '';
has tls       => undef;
has user      => '';

sub server {
  my ($self, $server) = @_;
  my $old = $self->{server} || '';

  Scalar::Util::weaken($self);
  return $old unless defined $server;
  return $self if $old and $old eq $server;
  $self->{server} = $server;
  return $self unless $self->{stream_id};
  $self->disconnect(
    sub {
      $self->connect(sub { });
    }
  );
  $self;
}

=head1 METHODS

=head2 connect

  $self = $self->connect(\&callback);

Will login to the IRC L</server> and call C<&callback> once connected. The
C<&callback> will be called once connected or if it fail to connect. The
second argument will be an error message or empty string on success.

=cut

sub connect {
  my ($self, $cb) = @_;
  my ($host, $port) = split /:/, $self->server;
  my @tls;

  if ($self->{stream_id}) {
    $self->$cb('');
    return $self;
  }

  if (my $tls = $self->tls) {
    push @tls, tls      => 1;
    push @tls, tls_ca   => $tls->{ca} if $tls->{ca};       # not sure why this should be supported, but adding it anyway
    push @tls, tls_cert => $tls->{cert} || DEFAULT_CERT;
    push @tls, tls_key  => $tls->{key} || DEFAULT_KEY;
  }

  $port ||= 6667;
  $self->{buffer} = '';
  $self->{debug_key} ||= "$host:$port";
  $self->register_default_event_handlers;

  if (OFFLINE) {
    $self->write(PASS => $self->pass, sub { }) if length $self->pass;
    $self->write(NICK => $self->nick, sub { });
    $self->write(USER => $self->user, 8, '*', ':' . $self->name, sub { });
    $self->$cb('');
    return $self;
  }

  Scalar::Util::weaken($self);
  $self->{stream_id} = $self->ioloop->client(
    address => $host,
    port    => $port,
    @tls,
    sub {
      my ($loop, $err, $stream) = @_;

      if ($err) {
        delete $self->{stream_id};
        return $self->$cb($err);
      }

      $stream->timeout(0);
      $stream->on(
        close => sub {
          $self or return;
          warn "[$self->{debug_key}] : close\n" if DEBUG;
          delete $self->{stream};
          delete $self->{stream_id};
          $self->emit('close');
        }
      );
      $stream->on(
        error => sub {
          $self or return;
          $self->ioloop or return;
          $self->ioloop->remove(delete $self->{stream_id});
          $self->emit(error => $_[1]);
        }
      );
      $stream->on(read => sub { $self->_read($_[1]) });

      $self->{stream} = $stream;
      $self->ioloop->delay(
        sub {
          my $delay = shift;
          $self->write(PASS => $self->pass, $delay->begin) if length $self->pass;
          $self->write(NICK => $self->nick, $delay->begin);
          $self->write(USER => $self->user, 8, '*', ':' . $self->name, $delay->begin);
        },
        sub {
          $self->$cb('');
        }
      );
    }
  );

  return $self;
}

=head2 ctcp

  $str = $self->ctcp(@str);

This message will quote CTCP messages. Example:

  $self->write(PRIVMSG => nickname => $self->ctcp(TIME => time));

The code above will write this message to IRC server:

  PRIVMSG nickname :\001TIME 1393006707\001

=cut

sub ctcp {
  my $self = shift;
  local $_ = join ' ', @_;
  s/([\012\015\0\cP])/\cP$CTCP_QUOTE{$1}/g;
  s/\001/\\a/g;
  ":\001${_}\001";
}

=head2 disconnect

  $self->disconnect(\&callback);

Will disconnect form the server and run the callback once it is done.

=cut

sub disconnect {
  my ($self, $cb) = @_;

  if (my $tid = delete $self->{ping_tid}) {
    $self->ioloop->remove($tid);
  }

  if ($self->{stream}) {
    Scalar::Util::weaken($self);
    $self->{stream}->write(
      "QUIT\r\n",
      sub {
        $self->{stream}->close;
        $self->$cb if $cb;
      }
    );
  }
  else {
    $self->$cb if $cb;
  }

  $self;
}

=head2 register_default_event_handlers

  $self->register_default_event_handlers;

This method sets up the default L</DEFAULT EVENT HANDLERS> unless someone has
already subscribed to the event.

=cut

sub register_default_event_handlers {
  my $self = shift;

  Scalar::Util::weaken($self);
  for my $event (@DEFAULT_EVENTS) {
    next if $self->has_subscribers($event);
    $self->on($event => $self->can($event));
  }
}

=head2 write

  $self->write(@str, \&callback);

This method writes a message to the IRC server. C<@str> will be concatenated
with " " and "\r\n" will be appended. C<&callback> is called once the message is
delivered over the stream. The second argument to the callback will be
an error message: Empty string on success and a description on error.

=cut

sub write {
  no warnings 'utf8';
  my $cb   = ref $_[-1] eq 'CODE' ? pop : sub { };
  my $self = shift;
  my $buf  = Unicode::UTF8::encode_utf8(join(' ', @_), sub { $_[0] });

  Scalar::Util::weaken($self);
  if (OFFLINE) {
    $self->{to_irc_server} .= "$buf\r\n";
    $self->$cb('');
  }
  elsif (ref $self->{stream}) {
    warn "[$self->{debug_key}] <<< $buf\n" if DEBUG;
    $self->{stream}->write("$buf\r\n", sub { $self->$cb(''); });
  }
  else {
    $self->$cb('Not connected');
  }

  $self;
}

=head1 DEFAULT EVENT HANDLERS

=head2 ctcp_ping

Will respond to the sender with the difference in time.

  Ping reply from $sender: 0.53 second(s)

=cut

sub ctcp_ping {
  my ($self, $message) = @_;
  my $ts   = $message->{params}[1];
  my $nick = IRC::Utils::parse_user($message->{prefix});

  return $self unless $ts;
  return $self->write('NOTICE', $nick, $self->ctcp(PING => $ts));
}

=head2 ctcp_time

Will respond to the sender with the current localtime. Example:

  TIME Fri Feb 21 18:56:50 2014

NOTE! The localtime format may change.

=cut

sub ctcp_time {
  my ($self, $message) = @_;
  my $nick = IRC::Utils::parse_user($message->{prefix});

  $self->write(NOTICE => $nick, $self->ctcp(TIME => scalar localtime));
}

=head2 ctcp_version

Will respond to the sender with:

  VERSION Mojo-IRC $VERSION

NOTE! Additional information may be added later on.

=cut

sub ctcp_version {
  my ($self, $message) = @_;
  my $nick = IRC::Utils::parse_user($message->{prefix});

  $self->write(NOTICE => $nick, $self->ctcp(VERSION => 'Mojo-IRC', $VERSION));
}

=head2 irc_nick

Used to update the L</nick> attribute when the nick has changed.

=cut

sub irc_nick {
  my ($self, $message) = @_;
  my $old_nick = ($message->{prefix} =~ /^[~&@%+]?(.*?)!/)[0] || '';

  if (lc $old_nick eq lc $self->nick) {
    $self->nick($message->{params}[0]);
  }
}

=head2 irc_notice

Responds to the server with "QUOTE PASS ..." if the notice contains "Ident
broken...QUOTE PASS...".

=cut

sub irc_notice {
  my ($self, $message) = @_;

  # NOTICE AUTH :*** Ident broken or disabled, to continue to connect you must type /QUOTE PASS 21105
  if ($message->{params}[0] =~ m!Ident broken.*QUOTE PASS (\S+)!) {
    $self->write(QUOTE => PASS => $1);
  }
}

=head2 irc_ping

Responds to the server with "PONG ...".

=cut

sub irc_ping {
  my ($self, $message) = @_;
  $self->write(PONG => $message->{params}[0]);
}

=head2 irc_rpl_welcome

Used to get the hostname of the server. Will also set up automatic PING
requests to prevent timeout and update the L</nick> attribute.

=cut

sub irc_rpl_welcome {
  my ($self, $message) = @_;
  $self->nick($message->{params}[0]);

  Scalar::Util::weaken($self);
  $self->real_host($message->{prefix});
  $self->{ping_tid} ||= $self->ioloop->recurring(
    $self->{ping_pong_interval} || 60,    # $self->{ping_pong_interval} is EXPERIMENTAL
    sub {
      $self->write(PING => $self->real_host);
    }
  );
}

=head2 err_nicknameinuse

This handler will add "_" to the failed nick before trying to register again.

=cut

sub err_nicknameinuse {
  my ($self, $message) = @_;
  my $nick = $message->{params}[1];

  $self->nick($nick . '_');
  $self->write(NICK => $self->nick, sub { });
}

sub DESTROY {
  my $self   = shift;
  my $ioloop = $self->ioloop or return;
  my $tid    = $self->{ping_tid};
  my $sid    = $self->{stream_id};

  $ioloop->remove($sid) if $sid;
  $ioloop->remove($tid) if $tid;
}

# Can be used in unittest to mock input data:
# $irc->_read($bytes);
sub _read {
  my $self = shift;

  no warnings 'utf8';
  $self->{buffer} .= Unicode::UTF8::decode_utf8($_[0], sub { $_[0] });

  while ($self->{buffer} =~ s/^([^\r\n]+)\r\n//m) {
    warn "[$self->{debug_key}] >>> $1\n" if DEBUG;
    my $message = $self->parser->parse($1);
    my $method = $message->{command} || '';

    if ($method =~ /^\d+$/) {
      $self->emit("irc_$method" => $message);
      $method = IRC::Utils::numeric_to_name($method) or next;
    }

    $method = "irc_$method" if $method !~ /^(CTCP|ERR)_/;
    $self->emit(lc($method) => $message);
    $self->emit(irc_error => $message) if $method =~ /^ERR_/;
  }
}

if (OFFLINE) {
  *from_irc_server = \&_read;
}

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Marcus Ramberg - C<mramberg@cpan.org>

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
