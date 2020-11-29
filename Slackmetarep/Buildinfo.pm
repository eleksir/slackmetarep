package Slackmetarep::Buildinfo;

use strict;
use warnings;
use vars qw/$VERSION/;
use English qw( -no_match_vars );
use Carp;

use JSON::XS;
use Slackmetarep::Conf qw(loadConf);

use Exporter qw(import);
our @EXPORT_OK = qw(buildinfo);

$VERSION = '1.0';

my $c = loadConf();

sub buildinfo ($) {
	my $repo = shift;
	my ($status, $content, $msg) = ('400', 'text/plain', "Bad Request?\n");

	return ($status, $content, $msg) unless ($repo =~ /\//xmsg);

	my ($config, $package) = split(/\//xms, $repo);

	unless (defined($c->{buildinfo}->{$config})) {
		$msg = "Config repo $config is not defined in config.\n";
		return ($status, $content, $msg);
	}

	open (my $jhandle, '<', $c->{buildinfo}->{$config}) or do {
		$status = '500';
		$msg = "Unable to open $c->{buildinfo}->{$config}; $OS_ERROR\n";
		carp '[FATA] ' . $msg;
		return ($status, $content, $msg);
	};

	my $len = (stat($c->{buildinfo}->{$config}))[7];
	my $json;
	my $readlen = read ($jhandle, $json, $len);
	close $jhandle; ## no critic (InputOutput::RequireCheckedSyscalls

	unless (defined($readlen)) {
		$status = '500';
		$msg = "Unable to read $c->{buildinfo}->{$config}: $OS_ERROR";
		carp '[FATA] ' . $msg;
		return ($status, $content, $msg);
	}

	if ($len != $readlen) {
		$status = '500';
		$msg = "Size of $c->{buildinfo}->{$config} $len bytes but actually read $readlen bytes";
		carp '[FATA] ' . $msg;
		return ('500', $content, "Unable to read $c->{buildinfo}->{$config}\n");
	}

	my $j = eval { decode_json($json) } or do {
		$status = '500';
		$msg = "Error during decoding $c->{buildinfo}->{$config}; $EVAL_ERROR\n";
		carp '[FATA] ' . $msg;
		return ($status, $content, $msg);
	};

	unless (defined($j->{$package})) {
		$msg = "$package is not defined in config for $config.\n";
		carp '[ERRO] ' . $msg;
		return ($status, $content, $msg);
	}

	$json = JSON::XS->new->pretty->canonical->indent(1)->encode($j->{$package}) or do {
		$status = '500';
		$msg = "Unable to encode json.\n";
		carp '[ERRO] ' . $msg;
		return ($status, $content, $msg);
	};

	$status = '200';
	$content = 'application/json';
	$msg = $json;
	return ($status, $content, $msg);
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
