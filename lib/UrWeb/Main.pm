#!/usr/bin/env perl

package UrWeb::Main;

use strict;
use warnings;

use UR;
use Dancer;
use Dancer::ModuleLoader;

# Here we set Dancer's Document Root to be relative
# to where ur-web runs.  This will provide trivial
# default files.  UR Namespaces will have Dancer
# Handlers.pm that probably redefine these.
my $appdir = dirname dirname __FILE__;
set appdir => $appdir;
set public => path($appdir,'public');
set views  => path($appdir,'views');
# 'core' logs debug, warning, error and Dancer too
set log => "core";
# Log to a file in appdir/logs
set logger => "console";
# If warnings is 1, then perl warn results in 500 error in the browser.
# We want to keep those quiet and have them server side for debugging.
set warnings => 0;
# Send errors to the browser.
set show_errors => 1;
set startup_info => 1;

# In production, write to a log file
if ( setting('environment') eq 'production') {
    eval {
        set logger => "file";
        set log_path => "/var/log/ur-web";
    };
    if ($@) {
        # Something about Dancer::Error hooks into die() I think.  I have to warn messages and exit
        # instead of die()ing.
        warn "Error setting log_path: $@";
        exit 1;
    }
}

# How can we load route handlers from other modules, contained
# within their UR namespaces?  I thought maybe we could parse namespace
# out of a URL and load dynamically, but I couldn't get that to work.
# Then I thought maybe a command line option passed to Main.psgi,
# but I can't figure out how to pass args to Main.psgi.  So the environment
# will have to do for now.
my @ns = split(/\s+/,$ENV{URWEB_NAMESPACES}) if ( defined $ENV{URWEB_NAMESPACES} );
foreach my $ns (@ns) {
    $ns = ucfirst(lc($ns));
    warn "load $ns handlers";
    my ($res,$error) = Dancer::ModuleLoader->load( $ns . "::Dancer::Handlers" );
    unless ($res) {
        # I don't know why, but if I die() here, all I see is ERROR: on the CLI, no message.
        warn "Error loading UR Namespace $ns: $error";
        exit 1;
    }
}

# This is the default ur-web route handler.  If we hit this, it indicates that
# the UR Namespace we're serving doesn't have a route handler that it should.
any qr{.*} => sub {
    unless (@ns) {
        my $msg = "No UR namespaces have been loaded.  Make sure you have a UR namespace installed and run ur-web with URWEB_NAMESPACES populated.";
        return template 'error.tt' => { message => $msg };
    }
    my $msg = "No UR namespace route handler matched this request.";
};

warn "start";
start;
