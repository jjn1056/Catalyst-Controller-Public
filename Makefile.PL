use strict;
use warnings;
use ExtUtils::MakeMaker 6.30;
 
my %WriteMakefileArgs = (
  "NAME" => "Catalyst::Controller::Public",
  "DISTNAME" => "Catalyst-Controller-Public",
  "ABSTRACT" => "A Public file serving Catalyst Controller",
  "AUTHOR" => "John Napiorkowski <jjnapiork\@cpan.org>",
  "VERSION_FROM" => 'lib/Catalyst/Controller/Public.pm',
  "LICENSE" => "perl",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "PREREQ_PM" => {
    'Moose' => '2.1403',
    'MooseX::MethodAttributes' => '0.29',
    'Catalyst' => '5.90082',
    'Plack' => '1.0033',
  },
  "TEST_REQUIRES" => {
    "Test::Most" => '0.33',
  },
  "test" => {
    "TESTS" => "t/*.t"
  }
);
 
unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}
 
unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}
 
delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };
 
WriteMakefile(%WriteMakefileArgs);
