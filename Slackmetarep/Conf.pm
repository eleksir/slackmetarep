package Slackmetarep::Conf;
# Loads json formatted config

use 5.020;                                                           ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open    qw (:std :utf8);
use English qw ( -no_match_vars );
use Encode  qw (encode);
use JSON::XS ();

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (LoadConf);

sub LoadConf {
	my $file = 'data/config.json';
	open my $FILEHANDLE, '<', $file || die "[FATA] No conf at $file: $OS_ERROR\n"; ## no critic (ErrorHandling::RequireUseOfExceptions)

	# Use binmode in order to get amount of read bytes (not chars!) from read()
	binmode $FILEHANDLE;
	my $len = (stat $file) [7];
	my $json;
	my $readlen = read $FILEHANDLE, $json, $len;
	$json = encode 'UTF-8', $json;

	unless (defined $readlen) {
		close $FILEHANDLE;                                   ## no critic (InputOutput::RequireCheckedSyscalls)
		die "[FATA] Unable to read $file: $OS_ERROR\n";      ## no critic (ErrorHandling::RequireUseOfExceptions)
	}

	if ($readlen != $len) {
		close $FILEHANDLE;                                   ## no critic (InputOutput::RequireCheckedSyscalls)
		die "[FATA] File $file is $len bytes on disk, but we read only $readlen bytes\n"; ## no critic (ErrorHandling::RequireUseOfExceptions)
	}

	close $FILEHANDLE;                                           ## no critic (InputOutput::RequireCheckedSyscalls)

	my $j = JSON::XS->new->utf8->relaxed;
	my $config = eval { $j->decode ($json); };

	unless (defined $config) {
		die "[FATA] File $file does not contain a valid json data: $EVAL_ERROR\n"; ## no critic (ErrorHandling::RequireUseOfExceptions)
	}

	return $config;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
