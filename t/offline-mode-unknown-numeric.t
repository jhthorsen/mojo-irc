BEGIN { $ENV{MOJO_IRC_OFFLINE} = 1 }
use Mojo::Base -strict;
use Mojo::IRC;
use Test::More;

my $irc = Mojo::IRC->new(nick => 'test123', server => 'tamarou');
my @events;

$irc->connect(sub { });

for my $event (
  qw(
  irc_275 irc_311 irc_312 irc_317
  irc_318 irc_319 irc_rpl_endofwhois
  irc_rpl_whoischannels irc_rpl_whoisidle
  irc_rpl_whoisserver irc_rpl_whoisuser
  )
  )
{
  $irc->on($event => sub { push @events, $event });
}

$irc->from_irc_server(<<"HERE");
:ford.tamarou.com 311 test123 test123 ~my 1.2.3.4.foo.com * :Test 123\r
:ford.tamarou.com 319 test123 test123 :#mojo\r
:ford.tamarou.com 312 test123 test123 ford.tamarou.com :Home of the Drama Llamas\r
:ford.tamarou.com 275 test123 test123 :is connected via SSL (secure link)\r
:ford.tamarou.com 317 test123 test123 0 1423419560 :seconds idle, signon time\r
:ford.tamarou.com 318 test123 test123 :End of /WHOIS list.\r
HERE

is_deeply(
  \@events,
  [
    qw(
      irc_311 irc_rpl_whoisuser
      irc_319 irc_rpl_whoischannels
      irc_312 irc_rpl_whoisserver
      irc_275
      irc_317 irc_rpl_whoisidle
      irc_318 irc_rpl_endofwhois
      )
  ],
  '_read() parsed all lines',
);

done_testing;
