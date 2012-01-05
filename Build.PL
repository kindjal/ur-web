#! /usr/bin/env perl

use Module::Build;

my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
      code => <<'SUBCLASS' );

    use File::Copy::Recursive qw/dircopy fcopy/;
    sub ACTION_install {
        my $self = shift;

        fcopy('lib/config.yml','blib/lib/UrWeb/config.yml') or die $!;
        dircopy('lib/public','blib/lib/UrWeb/public') or die $!;
        dircopy('lib/views','blib/lib/UrWeb/views') or die $!;
        dircopy('lib/environments','blib/lib/UrWeb/environments') or die $!;

        $self->SUPER::ACTION_install;
    }
SUBCLASS


#my $build = Module::Build->new(
my $build = $class->new(
  module_name => 'UrWeb',
  license => 'gpl',
  dist_version => '0.1',
  dist_abstract => 'A standalone UR Web application',
  scripts => [ 'bin/ur-web' ],
  build_requires => {
    'Module::Build' => '',
    'UR' => '0.31',
  },
  requires => {
    'UR' => '0.31',
  },
);

$build->create_build_script;
