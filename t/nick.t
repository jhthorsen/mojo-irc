use strict;
use warnings;
use Mojo::IRC;
use Test::More;

plan tests => 10;

my $irc = Mojo::IRC->new(nick => 'test123', stream => dummy_stream());

{
  is $irc->change_nick, $irc, 'invalid change_nick';
  is $irc->change_nick('test123'), $irc, 'change_nick to same nick';
  is_deeply \@main::buf, [], 'no data written to irc server when no change';

  is $irc->change_nick('fooman'), $irc, 'change_nick to fooman';
  is $irc->nick, 'test123', 'nick() is still test123';
  is_deeply(
    \@main::buf,
    ["NICK fooman\r\n"],
    'change nick command written to irc',
  );
}

{
  @main::buf = ();
  local $irc->{stream} = undef;
  $irc->change_nick('fooman');
  is_deeply \@main::buf, [], 'no data written to irc server when not connected';
  is $irc->nick, 'fooman', 'nick() is fooman since not conneted';
}

{
  $irc->irc_nick({
    prefix => 'ads!user@host',
    params => ['newnick'],
  });
  is $irc->nick, 'fooman', 'nick() did not change to newnick';

  $irc->irc_nick({
    prefix => 'fooman!user@host',
    params => ['foowoman'],
  });
  is $irc->nick, 'foowoman', 'nick() changed to foowoman';
}

sub dummy_stream {
  eval "package Dummy::Stream; sub write { shift; push \@main::buf, shift; shift->() } 1";
  bless {}, "Dummy::Stream";
}
