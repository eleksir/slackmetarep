## no critic (Modules::RequireExplicitPackage), it is a module
use 5.018;
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);

# Application modules
use lib qw (. ./vendor_perl ./vendor_perl/lib/perl5);
use Slackmetarep::Conf qw (LoadConf);
use Slackmetarep::Upload qw (Upload);
use Slackmetarep::Metagen qw (Metagen);
use Slackmetarep::Buildinfo qw (BuildInfo);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);

my $CONF = LoadConf ();

my $prefix = $CONF->{api}->{prefix};

if ($CONF->{api}->{prefix} eq '/') {
	$prefix = '';
}

my $app = sub { ## no critic (Modules::RequireEndWithOne), it is not a module
	my $env = shift;

	my $msg = "Your Opinion is very important for us, please stand by.\n";
	my $status = '404';
	my $content = 'text/plain';

	if ($env->{PATH_INFO} =~ /$prefix\/upload\/(.+)/xmsg) {
		my $upload = $1;
		($status, $content, $msg) = ('400', $content, "Bad Request?\n");

		if (defined($env->{HTTP_AUTH}) && ($env->{HTTP_AUTH} eq $CONF->{upload}->{auth})) {
			if (($upload !~ /\.\./xmsg) && ($upload =~ /^[_\-\+\/\.[:alnum:]]+$/xmsg)) {
				if (defined($env->{CONTENT_LENGTH}) && ($env->{CONTENT_LENGTH} > 0)) {
					($status, $content, $msg) = Upload ($env->{'psgi.input'}, $env->{CONTENT_LENGTH}, $upload);
				}
			} else {
				$msg = "Something wrong with upload path.\n";
			}
		} else {
			($status, $content, $msg) = ('403', $content, "You're not allowed here. Fuck off.\n");
		}
	} elsif ($env->{PATH_INFO} eq "$prefix/metagen") {
		if (defined($env->{HTTP_REPO})) {
			($status, $content, $msg) = Metagen ($env->{HTTP_REPO});
		}
	} elsif ($env->{PATH_INFO} eq "$prefix/buildinfo") {
		if (defined($env->{HTTP_REPO})) {
			($status, $content, $msg) = BuildInfo ($env->{HTTP_REPO});
		}
	}


	return [
		$status,
		[ 'Content-Type' => $content, 'Content-Length' => length $msg ],
		[ $msg ],
	];
};

__END__
# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
