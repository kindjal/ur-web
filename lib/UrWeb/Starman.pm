
package UrWeb::Starman;

use strict;
use warnings;

use UrWeb::Starman::Server;

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

sub run {
    my($self, $app) = @_;

    # Not sure this works here
    if ($ENV{SERVER_STARTER_PORT}) {
        require Net::Server::SS::PreFork;
        @Starman::Server::ISA = qw(Net::Server::SS::PreFork);
    }

    # This is really all we care about, that we use our Starman/Server.pm
    UrWeb::Starman::Server->new->run($app, {%$self});
}

1;
