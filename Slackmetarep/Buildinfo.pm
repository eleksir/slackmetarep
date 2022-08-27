package Slackmetarep::Buildinfo;

use 5.020; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use feature qw (signatures);  # no longer experimental in v5.36.0
no warnings qw (experimental::signatures); ## no critic (TestingAndDebugging::ProhibitNoWarnings)

use utf8;
use open     qw (:std :utf8);
use English  qw ( -no_match_vars );

use Carp     qw (carp);
use Encode   qw (encode);
use JSON::XS    ();

use Slackmetarep::Conf qw (LoadConf);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (BuildInfo);

my $c = LoadConf ();

sub BuildInfo ($repo) {
	my ($status, $content, $msg) = ('400', 'text/plain', "Bad Request?\n");

	# Request cosists of repo/package, so it must contain slash
	unless ($repo =~ /\//xmsg) {
		return $status, $content, $msg;
	}

	my ($config, $package) = split /\//xms, $repo;

	unless (defined $c->{buildinfo}->{$config}) {
		$msg = "Config repo $config is not defined in config.\n";
		return $status, $content, $msg;
	}

	open (my $jhandle, '<', $c->{buildinfo}->{$config}) or do {
		$msg = "Unable to open $c->{buildinfo}->{$config}: $OS_ERROR\n";
		carp '[FATA] ' . $msg;
		return '500', $content, $msg;
	};

	my $len = (stat $c->{buildinfo}->{$config})[7];
	my $json;
	# Use binmode in order to get read bytes (not chars!) from read()
	binmode $jhandle;
	my $readlen = read $jhandle, $json, $len;
	close $jhandle; ## no critic (InputOutput::RequireCheckedSyscalls

	unless (defined $readlen) {
		$msg = "Unable to read $c->{buildinfo}->{$config}: $OS_ERROR";
		carp '[FATA] ' . $msg;
		return '500', $content, $msg;
	}

	if ($len != $readlen) {
		$msg = "Size of $c->{buildinfo}->{$config} $len bytes but actually read $readlen bytes";
		carp '[FATA] ' . $msg;
		return '500', $content, "Unable to read $c->{buildinfo}->{$config}\n";
	}

	# Make sure that we have utf-8 text here
	$json = encode 'UTF-8', $json;

	# Use relaxed decoder, we don't want to mess with human errors, right?
	my $j = eval {
		my $jq = JSON::XS->new->utf8->relaxed;
		$jq->decode ($json);
	};

	unless (defined $j) {
		$msg = "Error during decoding $c->{buildinfo}->{$config}; $EVAL_ERROR\n";
		carp '[FATA] ' . $msg;
		return '500', $content, $msg;
	}

	$json = '';

	unless (defined $j->{$package}) {
		$msg = "$package is not defined in config for $config.\n";
		carp '[ERRO] ' . $msg;
		return $status, $content, $msg;
	}

	# Use small indentation, just 1 space and default formatting
	$msg = eval {
		my $jq = JSON::XS->new->pretty->canonical->indent (1);
		$jq->encode ($j->{$package});
	};

	unless (defined $msg) {
		$msg = "Unable to encode json.\n";
		carp '[ERRO] ' . $msg;
		return '500', $content, $msg;
	}

	return '200', 'application/json', $msg;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
