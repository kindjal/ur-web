#! /usr/bin/env perl

use Module::Build;

my $build = Module::Build->new(
  module_name => 'UrWeb',
  license => 'gpl',
  dist_version => '0.1',
  dist_abstract => 'A standalone UR Web application',
  scripts => [ 'bin/ur-web.pl' ],
  build_requires => {
    'Module::Build' => '',
    'UR' => '0.31',
  },
  requires => {
    'UR' => '0.31',
  },
);

$build->create_build_script;
