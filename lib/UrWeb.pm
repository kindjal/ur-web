
package UrWeb;

use strict;
use warnings;

use UR;
use UrWeb::Starman;
use UrWeb::Runner;

use File::Basename qw/ dirname /;
use Sys::Hostname;

# "Unassigned" ports from iana.org
my @AVAILABLE_PORTS = (8089, 8090, 8092, 8093, 8094, 8095,
                       9096, 8098, 8099, 8102, 8103, 8104,
                       8105, 8106, 8107, 8108, 8109, 8110,
                       8111, 8112, 8113, 8114);

class UrWeb {
    is  => 'Command::V2',
    has_optional => [
        port => {
            is    => 'Number',
            default_value => '8090',
            doc   => 'tcp port for internal server to listen'
        },
        env => {
            is    => 'Text',
            valid_values => ['development','production'],
            doc   => 'run mode, development enables reloading changed files',
        },
        fixed_port => {
            is    => 'Boolean',
            default_value => 0,
            doc   => 'force the use of the same port',
        },
        workers => {
            is    => 'Number',
            default_value => 20,
            doc   => 'specify the number of worker processes',
        },
        single_request => {
            is    => 'Boolean',
            default_value => 0,
            doc   => 'specify that each worker handle one request and exit',
        }
    ],
};

sub execute {
    my $self = shift;
    $self->determine_port;
    $self->run_starman;
}

sub psgi_path {
    my $self = shift;
    my $module_path = $self->__meta__->module_path;
    $module_path =~ s/.pm//;
    return $module_path;
}

sub determine_port {
    my ($self) = @_;
    return if ($self->fixed_port);
    unshift ( @AVAILABLE_PORTS, $self->port );
    $self->port(undef);
    foreach ( @AVAILABLE_PORTS ) {
        $self->status_message( sprintf ( "Checking port %d to ensure it is unused.\n", $_ ) );
        my $open_socket = IO::Socket::INET->new(
            LocalAddr => 'localhost',
            LocalPort => $_,
            Proto => 'tcp'
        );
        if ( defined $open_socket ) {
            $open_socket->close();
            $self->port($_);
            $self->status_message( sprintf( "Selected port: %d\n", $self->port ) );
            last;
        }
        $self->status_message( sprintf( "Port %d in use. Trying next choice.\n", $_) );
    }
    die "None of the offered ports are available. Add more ports to Web app or specify a different port." unless ( $self->port );
}

sub run_starman {
    my ($self) = @_;

    my $runner = UrWeb::Runner->new(
        server => 'UrWeb::Starman',
        env    => $self->env,
    );

    my $psgi_path = $self->psgi_path . '/Main.pm';
    my %options = (
        '--app' => $psgi_path,
        '--port' => $self->port,
        '--workers' => $self->workers,
        '--single_request' => $self->single_request
    );
    if ($self->{env} and $self->{env} eq 'development') {
        $options{'-r'} = '';
        $options{'-R'} = $self->psgi_path;
    }
    $runner->parse_options( %options );
    $runner->run;
}

1;
