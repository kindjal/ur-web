
package SDM::Dancer::Handlers;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

use Dancer ':syntax';

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
  default_route static_content add_handler update_handler delete_handler rest_handler
);

sub url_to_type {
    join(
        '::',
        map {
            $_ = ucfirst;
            s/-(\w{1})/\u$1/g;
            $_;
          } split( '/', $_[0] )
    );
}

warn "SDM::Dancer::Handlers loaded";

# Default route handler
#get '/' => sub {
get '/' => sub {
    warn "default route";
    return default_route();
};

sub default_route {
    warn "Using default route handler";
    #redirect "/view/search/status.html";
    "Default search page not yet implemented";
}

sub static_content {
    warn "Using static content route handler: " . Data::Dumper::Dumper splat;
    #my ($file) = @{ params->{splat} };
    my ($file) = splat;
    #$file =~ s/\/res//;
    warning "look for $file";
    return send_file($file);
}

sub add_handler {
    my $self = shift;
    # What kind of object are we adding?
    my $class = delete params->{class};
    # Don't confuse UR, let it come up with the id.
    delete params->{id};
    # Everything's a Set, no need to say it.
    $class =~ s/::Set$//;

    # Load the requested namespace
    my ($namespace,$toss) = split(/\:\:/,$class,2);
    $namespace = ucfirst(lc($namespace));
    load_module $namespace;

    my $obj;
    eval {
        $obj = $class->create( params );
        unless ($obj) {
            die __PACKAGE__ . " Failed to create object";
        }
        UR::Context->commit();
    };
    if ($@) {
        warn "error: " . Data::Dumper::Dumper $@;
        return send_error();
    }
    warn "returning: " . $obj->id;
    # Send back the ID, which should be used by
    # datatables editable as a new row id
    return $obj->id;
}

sub update_handler {
    my $self = shift;

    # Load the requested namespace
    my $class = delete params->{class};
    my ($namespace,$toss) = split(/\:\:/,$class,2);
    $namespace = ucfirst(lc($namespace));
    load_module $namespace;

    my $attr = params->{columnName};
    my $value = params->{value};
    $class =~ s/::Set//g;

    my $msg;
    eval {
        my $obj = $class->get( id => params->{id} );
        unless ($obj) {
            die __PACKAGE__ . " No object found for id " . params->{id};
        }
        $msg = $value;
        $obj->$attr( $value );
        $obj->last_modified( time2str(q|%Y-%m-%d %H:%M:%S|,time()) );
        UR::Context->commit();
    };
    if ($@) {
        warn "error: " . Data::Dumper::Dumper $@;
        return send_error();
    }
    return $msg;
}

sub delete_handler {
    my $self = shift;
    my $class = delete params->{class};
    $class =~ s/::Set//g;

    # Load the requested namespace
    my ($namespace,$toss) = split(/\:\:/,$class,2);
    $namespace = ucfirst(lc($namespace));
    load_module $namespace;

    eval {
        my $obj = $class->get( params );
        $obj->delete;
        UR::Context->commit();
    };
    if ($@) {
        warn "error: " . Data::Dumper::Dumper $@;
        return send_error();
    }
}

sub rest_handler {
    warn "Using REST API route handler";
    my ( $class, $perspective, $toolkit ) = @{ delete params->{splat} };
    # FIXME: appdir?
    my $appdir = setting('appdir');

    # This is in our XML/XSL UR stuff, should be made local to this package.
    $class = url_to_type($class);

    # Load the requested namespace
    my ($namespace,$toss) = split(/\:\:/,$class,2);
    #$namespace = ucfirst(lc($namespace));
    load_module $namespace;

    # Support our old REST scheme of view/namespace/object/set/perspective.toolkit
    # by removing ::Set, we assume everything is a Set now.
    $class =~ s/::Set//;

    $perspective =~ s/\.$toolkit$//g;

    # flatten these where only one arg came in (don't want x=>['y'], just x=>'y')
    my $args = params;
    for my $key ( keys %$args ) {
        if ( index( $key, '_' ) == 0 ) {
            delete $args->{$key};
            next;
        }
        my $value = $args->{$key};
    }

    # Begin building args for UR query.
    my %view_special_args;
    for my $view_key (grep {$_=~ m/^-/} keys %$args) {
        $view_special_args{substr($view_key,1,length($view_key))} = delete $args->{$view_key}; 
    }

    my $set;
    eval { $set = $class->define_set(%$args); };
    if ($@) {
        warn "invalid args";
        return send_error("Invalid arguments to define_set: $@",500);
    }
    unless ($set) {
        warn "no set found";
        return send_error("No object set found",500);
    }

    # Things get complicated here:
    #  - Table perspective is newer than others.  Assumes everything is a set.
    #  - Other perspectives should try a set and fall back to single object.
    #
    my $result = $set;
    # FIXME: select on UR::Object::Set::View::Table
    if ($perspective ne 'table') {
        my @m = $set->members;
        $result = shift @m;
    }
    unless ($result) {
        warn "no objects found";
        return send_error("No object found",500);
    }

    my %view_args = (
        perspective => $perspective,
        toolkit     => $toolkit
    );

    # FIXME:
    # This is the default UR XML -> XSL translation layer.
    # Default object views are XML documents transformed to HTML via XSL.
    if ( $toolkit eq 'xsl' || $toolkit eq 'html' ) {
        $view_args{'xsl_root'} = $appdir . '/xsl';    ## maybe move this to $res_path?
        $view_args{'xsl_path'} = '/static/xsl';
        $view_args{'html_root'} = $namespace->base_dir . '/View/Resource/Html/html';
        $view_args{'xsl_variables'} = {
            rest      => '/view',
            # Is this actually used?  I think this builds a URL in an old-fashioned
            # /view/$namespace/resource.html/foo.bar scheme that I'm not sure we do.
            resources => "/view/$namespace/resource.html"
        };
    }

    # All objects in UR have create_view
    # this probably ought to be revisited for performance reasons because it has to do a lot of hierarchy walking
    my $view;

    # Our first create_view attempt will find explicit Object View definitions.
    eval {
        $view = $result->create_view(%view_args, %view_special_args);
    };
    if ($@ or ! defined $view) {
        # Try again.
        warn "No view found: " . $@;
        $view_args{subject_class_name} = "UR::Object::Set";
        eval {
            $view = $result->create_view(%view_args, %view_special_args);
        };
    }
    if ($@ or ! defined $view) {
        # Try the default view
        warn "No view found: " . $@;
        warn "looking for default view";
        $view_args{perspective} = 'default';
        eval {
            $view = $result->create_view(%view_args, %view_special_args);
        };
    }
    if ($@) {
        return send_error "No view found: $@";
    }
    return send_error("No view found",404) unless ($view);

    return $view->content();
}

1;
