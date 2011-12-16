use Test::More;
use strict;
use warnings;

# the order is important
use UrWeb::Main;
use Dancer::Test;

plan skip_all => "Not yet sure how to test UrWeb.pm because it start()s at the end";

route_exists [GET => '/'], 'a route handler is defined for /';
response_status_is ['GET' => '/'], 200, 'response status is 200 for /';
done_testing();
