use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mojo-IRC',
  VERSION_FROM => 'lib/Mojo/IRC.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  PREREQ_PM => {
    'Mojolicious' => '4.00',
  },
  test => {
    TESTS => 't/*.t',
  },
);
