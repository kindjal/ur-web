
package UrWeb::Runner;

use base qw( Plack::Runner );

sub load_server {
    my($self, $loader) = @_;
    $self->{server}->new(@{$self->{options}});
}

1;
