use strict;
use warnings;
use Mojo::IRC;
use Test::More;

my $irc = Mojo::IRC->new(nick => 'fooman', stream => dummy_stream());

$irc->irc_nick({prefix => 'ads!user@host', params => ['newnick'],});
is $irc->nick, 'fooman', 'nick() did not change to newnick';

$irc->irc_nick({prefix => 'fooman!user@host', params => ['foowoman']});
is $irc->nick, 'foowoman', 'nick() changed to foowoman';

my %nicks = qw( ~ tilde & and @ at % percent + plus );
my $old   = $irc->nick;
while (my ($prefix, $new) = each %nicks) {
  $irc->irc_nick({prefix => "$prefix$old!user\@host", params => [$new]});
  is $irc->nick, $new, "nick() changed to $new";
  $old = $irc->nick;
}

sub dummy_stream {
  eval "package Dummy::Stream; sub write { shift; push \@main::buf, shift; shift->() } 1";
  bless {}, "Dummy::Stream";
}

done_testing;
