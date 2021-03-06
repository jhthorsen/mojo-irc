# Generated by git-ship. See 'git-ship --man' for help or https://github.com/jhthorsen/app-git-ship
use ExtUtils::MakeMaker;
my %WriteMakefileArgs = (
  NAME           => 'Mojo::IRC',
  AUTHOR         => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE        => 'artistic_2',
  ABSTRACT_FROM  => 'lib/Mojo/IRC.pm',
  VERSION_FROM   => 'lib/Mojo/IRC.pm',
  EXE_FILES      => [qw()],
  BUILD_REQUIRES => {},
  TEST_REQUIRES  => {'Test::More' => '0.88'},
  PREREQ_PM      => {
    'IRC::Utils'    => '0.12',
    'List::Util'    => '1.33',
    'Mojolicious'   => '7.54',
    'Parse::IRC'    => '1.20',
    'Unicode::UTF8' => '0.59'
  },
  META_MERGE => {
    'dynamic_config' => 0,
    'meta-spec'      => {version => 2},
    'resources'      => {
      bugtracker => {web => 'https://github.com/jhthorsen/mojo-irc/issues'},
      homepage   => 'https://github.com/jhthorsen/mojo-irc',
      repository => {
        type => 'git',
        url  => 'https://github.com/jhthorsen/mojo-irc.git',
        web  => 'https://github.com/jhthorsen/mojo-irc',
      },
    },
  },
  test => {S => (-e 'META.yml' ? 't/*.t' : 't/*.t xt/*.t')},
);

unless (eval { ExtUtils::MakeMaker->VERSION('6.63_03') }) {
  my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES};
  @{$WriteMakefileArgs{PREREQ_PM}}{keys %$test_requires} = values %$test_requires;
}

WriteMakefile(%WriteMakefileArgs);
