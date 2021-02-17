# ABSTRACT: Profile your Catalyst application with Devel::NYTProf
package CatalystX::Profile::NYTProf;
BEGIN {
  $CatalystX::Profile::NYTProf::VERSION = '0.01';
}
use Moose::Role;
use namespace::autoclean;
 
use CatalystX::InjectComponent;
use Data::UUID;
use DDP;
use Path::Tiny;


# Ick - find a better way to pass this around than a global var!
my $nytprof_output_dir;

after 'setup_finalize' => sub {
    my $self = shift;
    #$self->log->debug('Profiling is active');
    #DB::enable_profile();
    
    # Load Devel::NYTProf, but tell it not to start yet.  It will still want
    # to create an nytprof.out file immediately unless we tell it elsewhere.
    # We also need use_db_sub, because otherwise it can't profile code that
    # was compiled before Devel::NYTProf loaded.
    $ENV{NYTPROF} = "start=no:file=/dev/null:use_db_sub=1";
    require Devel::NYTProf;
    $self->log->debug("Loaded Devel::NYTProf");

    # FIXME: support reading this from the config
    my $conf = $self->config->{'Plugin::Profile::NYTProf'} || {};
    $nytprof_output_dir = $conf->{nytprof_out_dir} || 'nytprof_output';
    if (!-d $nytprof_output_dir) {
        $self->log->debug("Creating NYTProf output dir $nytprof_output_dir");
        Path::Tiny::path($nytprof_output_dir, "html")->mkpath;
    } else {
        $self->log->debug("OK, using NYTProf output dir $nytprof_output_dir");
    }
};
 
after 'setup_components' => sub {
    my $class = shift;
    CatalystX::InjectComponent->inject(
        into => $class,
        component => 'CatalystX::Profile::NYTProf::Controller::ControlProfiling',
        as => 'Controller::Profile'
    );
};

# Start a profile run when a request begins...
# FIXME: is this the best hook?  Want the Catalyst equivalent of a Dancer
# `before` hook.  `prepare_body` looks like a reasonable "we've read the
# request from the network, we're about to handle it" point.
after 'prepare_body' => sub {
    my $c = shift;

    # Don't try to profile requests to our profile viewing/managing URLs
    # as that would be a bit silly, wouldn't it?
    return if $c->request->path =~ m{^profile/};

    # Also don't profile requests for static content, for similar reasons
    return if $c->request->path =~ m{^static/};

    # We want to name all profile outputs safely and usefully, encoding
    # the request method, path, and timestamp, and a random number for some
    # uniqueness.
    my $path = $c->request->method . '_' . ($c->request->path || '/');
    $path =~ s{/}{_s_}g;
    $path =~ s{[^a-z0-9]}{_}gi;
    $path .= DateTime->now->strftime('%Y-%m-%d_%H:%M:%S');
    $path .= substr Data::UUID->new->create_str, 0, 8;
    $path = Path::Tiny::path($nytprof_output_dir, $path);
    DB::enable_profile($path);
    $c->log->debug("Profiling this run to $path");
    $c->log->debug("nytprof out dir was $nytprof_output_dir");
};

# And finalise it when the request is finished
after 'finalize_body' => sub {
    my $c = shift;
    $c->log->debug("finalize_body fired, stop profiling");
    # TODO: it should be a no-op to call these if we weren't profiling,
    # but should double-check that.
    DB::disable_profile();
    DB::finish_profile();

};


1;
