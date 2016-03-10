use Mojo::Base -strict;
use Data::Dumper;
use Parse::IRC;
use Test::More;

plan skip_all => 'This is not a real test' if $ENV{HARNESS_ACTIVE} or $ENV{HARNESS_VERSION};

my $msg    = readline STDIN;
my $struct = Parse::IRC::parse_irc($msg);
ok $struct, "parsed $msg";

local $Data::Dumper::Indent   = 1;
local $Data::Dumper::Terse    = 1;
local $Data::Dumper::Sortkeys = 1;
print Dumper($struct);

done_testing;
