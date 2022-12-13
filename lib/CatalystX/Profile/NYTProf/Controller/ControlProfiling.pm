# ABSTRACT: Control profiling within your application
package CatalystX::Profile::NYTProf::Controller::ControlProfiling;
BEGIN {
  $CatalystX::Profile::NYTProf::Controller::ControlProfiling::VERSION = '0.02';
}
use Moose;
use Path::Tiny qw(path);
use namespace::autoclean;

use Devel::NYTProf::Data;
use File::stat;
 
BEGIN { extends 'Catalyst::Controller' }
 
#use Devel::NYTProf;

# FIXME: how am I going to share this from the CatalystX plugin code
# to this controller code nicely?  Need both to get default values and be
# able to override in app config
my $nytprof_output_dir = 'nytprof_output';
my $nytprofhtml_path = '/home/davidp/perl5/bin/nytprofhtml';


sub auto : Private {
    my ($self, $c) = @_;
    $c->log->debug("auto action called");
}

sub globalregex :Regexp(.+) {
    my ($self, $c) = @_;
    $c->log->debug("globalregex fired");
    return 1;
}

sub index : Local {
    my ($self, $c) = @_;
    # ICK ICK ICK, get this in a nice template
    my $html = <<HTML;
<h1>NYTProf profiling management</h1>

<style>
table {
  border-collapse: collapse;
  font-size: 9px;
  font-family: Source Code Pro, monospace;
}
table td {
    padding: 3px;
}
</style>

<h2>Profiled requests...</h2>

<table border="1" cellspacing="5">
<tr>
<th>Method</th>
<th>Path</th>
<th>Time taken</th>
<th>Datetime</th>
<th>View</th>
</tr>
HTML

    opendir my $outdir, $nytprof_output_dir
        or die "Failed to opendir $nytprof_output_dir - $!";
    my @files = grep { $_ !~ /^(\.|html)/ } readdir $outdir;
    for my $file (
        sort {
            (stat path($nytprof_output_dir, $b))->ctime
            <=>
            (stat path($nytprof_output_dir, $a))->ctime
        } @files
    ) {
        my $title = $file;
        $title =~ s{_s_}{/}g;
        my ($method, $path ,$timestamp, $uuid) = split '_', $title, 4;
        my $datetime = scalar localtime( (stat path($nytprof_output_dir, $file))->ctime);

        # Get the execution time; do it in an eval in case the profile run
        # is incomplete/corrupt
        my $profile;
        eval {
            $profile = Devel::NYTProf::Data->new(
                { filename => path($nytprof_output_dir, $file) },
            )
        };
        my $duration = $profile 
            ? sprintf '%.4f secs', $profile->attributes->{profiler_duration}
            : "???";

        $html .= <<ROW;
<tr><td>$method</td><td>$path</td><td>$duration</td>
<td>$datetime</td>
<td><a href="/nytprof/show/$file/index.html">View</a></td>
</tr>
ROW
    }

    $html .= "</table";

    $c->response->body($html);
}


#sub show : Local {
#    my ($self, $c) = @_;
#sub show :Local :Regex('show/(.+)') {
sub show :Local {
    my ($self, $c, $profile_dir, $file) = @_;

    # FIXME: it would be cleaner to use arguments, but I can't remember how
    # to do the Catalyst equivalent of Dancer's get '/foo/**' => sub { ... }
    # to match /foo/bar, /foo/bar/index.html etc.
    #my $requested_path = $c->request->path;
    #$requested_path =~ s{^profile/show/}{};


    $file ||= 'index.html';

    my $profile_path = Path::Tiny::path(
        $nytprof_output_dir,
        $profile_dir,
    );
    my $profile_html_dir = Path::Tiny::path(
        $nytprof_output_dir,
        'html',
        $profile_dir,
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
        } else {
            $c->log->debug("Successfully generated HTML output");
        }
    }

    # OK, send the content
    # Should maybe consider letting Catalyst::Plugin::Static::Simple handle
    # serving the generated HTML - but we need to make sure it's generated
    # first anyway, so...
    $c->log->debug("Send HTML content from [$profile_html_dir][$file]");
    $c->response->body(
        Path::Tiny::path(
            $profile_html_dir,
            $file,
        )->slurp_utf8,
    );
}


 
1;
 
 
__END__
