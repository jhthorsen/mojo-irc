use strict;
use warnings;
use Mojo::IRC;
use Test::More;

plan tests => 2;

my $irc = Mojo::IRC->new(nick => 'fooman', stream => dummy_stream());

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
