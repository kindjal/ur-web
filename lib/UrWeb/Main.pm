#!/usr/bin/env perl

package UrWeb::Main;

use strict;
use warnings;

use UR;
use Dancer;
use Dancer::ModuleLoader;

my $appdir = dirname dirname __FILE__;
set appdir => $appdir;
set public => path($appdir,'public');

# Log more to the console
set log => "core";
set logger => "console";
# If warnings is 1, then perl warn results in 500 error
set warnings => 0;
# Send errors to the caller
set show_errors => 1;

# How can we load route handlers from other modules, contained
# within their UR namespaces?  I thought maybe we could parse namespace
# out of a URL and load dynamically, but I couldn't get that to work.
# Then I thought maybe a command line option passed to Main.psgi,
# but I can't figure out how to pass args to Main.psgi.  So the environment
# will have to do for now.
my @ns = split(/\s+/,$ENV{URWEB_NAMESPACES}) if ( defined $ENV{URWEB_NAMESPACES} );
foreach my $ns (@ns) {
    warn "load $ns handlers";
    my ($res,$error) = Dancer::ModuleLoader->load( $ns . "::Dancer::Handlers" );
    $res or die "Error loading UR Namespace $ns: $error";
}

start;
