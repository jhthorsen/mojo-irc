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

=head2 channels

  $self = $self->channels(sub { my ($self, $err, $channels) = @_; });

Will retrieve available channels on the IRC server. C<$channels> has this
structure on success:

  {
    "#convos" => {n_users => 4, topic => "[+nt] some cool topic"},
  }

NOTE: This might take a long time, if the server has a lot of channels.

=cut

sub channels {
  my ($self, $cb) = @_;
  my %channels;

  return $self->_write_and_wait(
    Parse::IRC::parse_irc("LIST"),
    {
      irc_rpl_listend => {},     # :hybrid8.debian.local 323 superman :End of /LIST
      irc_rpl_list    => sub {
        my ($self, $msg) = @_;
        $channels{$msg->{params}[1]} = {n_users => $msg->{params}[2], topic => $msg->{params}[3] // ''};
      },
    },
    sub {
      my ($self, $event, $err, $msg) = @_;
      my $n = 0;

      return $self->$cb($err || $msg->{params}[1] || $event, []) if $event =~ /^err_/;
      return $self->$cb('', \%channels);
    },
  );
}

=head2 join_channel

  $self = $self->join_channel($channel => sub { my ($self, $err, $info) = @_; });

Used to join an IRC channel. C<$err> will be false (empty string) on a
successful join. C<$info> can contain information about the joined channel:

  {
    topic    => "some cool topic",
    topic_by => "jhthorsen",
    users    => {
      jhthorsen => {mode => "@"},
      Superman  => {mode => ""},
    },
  }

NOTE! This method will fail if the channel is already joined. Unfortunately,
the way it will fail is simply by not calling the callback. This should be
fixed - Just don't know how yet.

=cut

sub join_channel {
  my ($self, $name, $cb) = @_;
  my $info = {topic => '', topic_by => '', users => {}};

  # err_needmoreparams and will not allow special "JOIN 0"
  return $self->tap($cb, "Cannot join without channel name.") unless $name;
  return $self->tap($cb, "Cannot join channel with spaces.") if $name =~ /\s/;
  return $self->_write_and_wait(
    Parse::IRC::parse_irc("JOIN $name"),
    {
      err_badchanmask     => {1 => $name},
      err_badchannelkey   => {1 => $name},
      err_bannedfromchan  => {1 => $name},    # :hybrid8.debian.local 474 superman #convos :Cannot join channel (+b)
      err_channelisfull   => {1 => $name},
      err_inviteonlychan  => {1 => $name},
      err_nosuchchannel   => {1 => $name},    # :hybrid8.debian.local 403 nick #convos :No such channel
      err_toomanychannels => {1 => $name},
      err_toomanytargets  => {1 => $name},
      err_unavailresource => {1 => $name},
      irc_479             => {1 => $name},    # Illegal channel name
      irc_rpl_endofnames  => {1 => $name},    # :hybrid8.debian.local 366 superman #convos :End of /NAMES list.
      irc_rpl_namreply    => sub {
        my ($self, $msg) = @_;
        $self->_parse_namreply($msg, $info->{users}) if $msg->{params}[2] eq $name;
      },
      irc_rpl_topic => sub {
        my ($self, $msg) = @_;
        $info->{topic} = $msg->{params}[2] if $msg->{params}[1] eq $name;
      },
      irc_rpl_topicwhotime => sub {
        my ($self, $msg) = @_;
        $info->{topic_by} = $msg->{params}[2] if $msg->{params}[1] eq $name;
      },
    },
    sub {
      my ($self, $event, $err, $msg) = @_;
      $self->$cb($event =~ /^(?:err_|irc_479)/ ? $err || $msg->{params}[2] || $event : '', $info);
    }
  );
}

=head2 nick

  $self = $self->nick($nick => sub { my ($self, $err) = @_; });
  $self = $self->nick(sub { my ($self, $err, $nick) = @_; });

Used to set or get the nick for this connection.

Setting the nick will change L</nick> I<after> the nick is actually
changed on the server.

=cut

sub nick {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my ($self, $nick) = @_;

  unless ($cb) {
    return $self->{nick} ||= $self->user unless defined $nick;
    $self->{nick} = $nick;
    return $self;
  }

  if ($nick) {
    if ($self->{stream}) {
      $self->_write_and_wait(
        Parse::IRC::parse_irc("NICK $nick"),
        {
          err_erroneusnickname => {0 => $nick},
          err_nickcollision    => {0 => $nick},
          err_nicknameinuse    => {0 => $nick},
          err_restricted       => {},
          err_unavailresource  => {},
          irc_nick             => {0 => $nick},    # :Superman12923!superman@i.love.debian.org NICK :Supermanx12923
        },
        sub {
          my ($self, $event, $err, $msg) = @_;
          $self->nick($nick) if $event eq 'irc_nick';
          $self->$cb($event =~ /^err_/ ? $err || $msg->{params}[2] || $event : '');
        }
      );
    }
    else {
      $self->nick($nick)->$cb('');
    }
  }
  else {
    $self->$cb('', $self->nick);
  }

  return $self;
}

sub _parse_namreply {
  my ($self, $msg, $users) = @_;

  for my $nick (sort { lc $a cmp lc $b } split /\s+/, $msg->{params}[3]) {
    $users->{$nick}{mode} = $nick =~ s/^([@~+*])// ? $1 : '';
  }
}

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
        return $self->$needle($msg) if ref $needle eq 'CODE';
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
