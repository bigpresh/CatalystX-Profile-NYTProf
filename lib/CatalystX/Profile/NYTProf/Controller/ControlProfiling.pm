# ABSTRACT: Control profiling within your application
package CatalystX::Profile::NYTProf::Controller::ControlProfiling;
BEGIN {
  $CatalystX::Profile::NYTProf::Controller::ControlProfiling::VERSION = '0.02';
}
use Moose;
use Path::Tiny;
use namespace::autoclean;
 
BEGIN { extends 'Catalyst::Controller' }
 
#use Devel::NYTProf;

# FIXME: how am I going to share this from the CatalystX plugin code
# to this controller code nicely?  Need both to get default values and be
# able to override in app config
my $nytprof_output_dir = 'nytprof_output';
my $nytprofhtml_path = '/home/davidp/perl5/bin/nytprofhtml';

sub index : Local {
    my ($self, $c) = @_;
    # ICK ICK ICK, get this in a nice template
    my $html = <<HTML;
<h1>NYTProf profiling management</h1>

<b>PATH: $nytprof_output_dir</b>

<h2>Profiled requests...</h2>

<ul>
HTML

    opendir my $outdir, $nytprof_output_dir
        or die "Failed to opendir $nytprof_output_dir - $!";
    while (my $filename = readdir $outdir) {
        next if $filename =~ /^\./;
        next if $filename eq 'html';
        my ($method, $title) = split '_', $filename, 2;
        $title =~ s{_s_}{/}g;
        $html .= qq{<li><a href="/profile/show/$filename/index.html">$method $title</a></li>};
    }
    $c->response->body($html);
}

sub show : Local {
    my ($self, $c) = @_;

    # FIXME: it would be cleaner to use arguments, but I can't remember how
    # to do the Catalyst equivalent of Dancer's get '/foo/**' => sub { ... }
    # to match /foo/bar, /foo/bar/index.html etc.
    my $requested_path = $c->request->path;
    $requested_path =~ s{^profile/show/}{};

    # We'll have a request for e.g. /profile/show/GET_foo...../index.html
    # We'll get the bits after '/profile/show/' in our arguments
    # We need to know the profile name, which is the first bit, to check
    # we have it, then we can serve up the content requested
    my ($profile, $html_path) = split '/', $requested_path;
    $c->log->debug("Serving HTML for profile $profile");
    $c->log->debug("Full HTML path requested: $html_path");
    $c->log->debug("at this point, output dir is $nytprof_output_dir");
    $c->log->debug("Path is " . $c->request->path);

    my $profile_path = Path::Tiny::path(
        $nytprof_output_dir,
        $profile,
    );
    my $profile_html_dir = Path::Tiny::path(
        $nytprof_output_dir,
        'html',
        $profile,
    );
    if (!-d $profile_html_dir) {
        # We need to run nytprofhtml first to generate the output
        $c->log->debug(
            "Generate HTML output for profile $profile_path"
            . " to $profile_html_dir",
        );
        system(
            $nytprofhtml_path,
            "--file=$profile_path",  "--out=$profile_html_dir",
        );
        if ($? != 0) {
            die sprintf "%s exited with value %d", $nytprofhtml_path, $?;
        }
    }

    # OK, send the content
    # Should maybe consider letting Catalyst::Plugin::Static::Simple handle
    # serving the generated HTML - but we need to make sure it's generated
    # first anyway...
    $c->log->debug("Send HTML content from $profile_html_dir");
    $c->response->body(
        Path::Tiny::path(
            $profile_html_dir,
            $html_path,
        )->slurp,
    );
}

sub profiles : Local {
    my ($self, $c) = @_;
    $c->body("TODO: list profiles");
}

sub enable_profiling : Local {
    my ($self, $c) = @_;
    $c->body("TODO: enable / disable profiling");
}
sub disable_profiling : Local {
    my ($self, $c) = @_;
    $c->body("TODO: enable / disable profiling");
}
 
 
1;
 
 
__END__
