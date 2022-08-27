package Slackmetarep::Upload;

use 5.020; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use feature 'signatures';  # no longer experimental in v5.36.0
no warnings qw (experimental::signatures); ## no critic (TestingAndDebugging::ProhibitNoWarnings)

use utf8;

use vars qw/$VERSION/;
use English qw ( -no_match_vars );
use Carp qw (carp);

use Fcntl qw (O_CREAT O_TRUNC O_WRONLY);
use Slackmetarep::Conf qw (LoadConf);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Upload);

my $c = LoadConf ();

sub Upload :lvalue ($input, $len, $name) {
	#	$input - file descriptor with data being uploaded
	#	$len   - expected data length (from client)
	#	$name  - upload "dir" and filename
	my ($status, $content, $msg) = ('400', 'text/plain', "Bad Request?\n");

	return ($status, $content, "No Content-Length supplied.\n") unless (defined $len);
	return ($status, $content, "No name supplied.\n")           unless (defined $name);

	my $d;
	($d, $name) = split /\//xms, $name, 2;

	unless ($name =~ /^[[:alnum:]_\-\+\.]+$/xmsg) {
		return $status, $content, "Name does not match pattern.\n";
	}

	my $match;

	foreach my $uploaddir (keys %{$c->{upload}->{dir}}) {
		warn "$d vs $uploaddir\n";
		if ($d eq $uploaddir) {
			$match = 1;
			last;
		}
	}

	# Incorrect destination in url
	unless ($match) {
		return $status, $content, "Incorrect destination dir.\n";
	}

	$name = sprintf '%s/%s', $c->{upload}->{dir}->{$d}, $name;

	if ($len > 0) {
		if (sysopen my $FH, $name, O_CREAT|O_TRUNC|O_WRONLY) {
			my $buf;
			my $readlen = 0;
			my $totalread = 0;
			my $buflen = 524288; # 512 kbytes, looks sane enough

			if ($len < $buflen) {
				$buflen = $len;
			}

			do {
				$readlen = $input->read ($buf, $buflen);

				my $written = syswrite $FH, $buf, $readlen;

				# Not enough free space?
				unless (defined $written) {
					close $FH; ## no critic (InputOutput::RequireCheckedSyscalls)
					unlink $name;
					$buf = '';
					carp "[FATA] Unable to write to $name: $OS_ERROR";

					return '500', $content, "An error has occured during upload: $OS_ERROR\n";
				}

				# Other error
				if ($readlen != $written) {
					close $FH; ## no critic (InputOutput::RequireCheckedSyscalls)
					unlink $name;
					$buf = '';
					carp "[FATA] Must write $readlen bytes, but actualy wrote $written bytes to $name";

					return '500', $content, "An error has occured during upload: $OS_ERROR\n";
				}

				$totalread += $readlen;
			} while ($readlen == $buflen);

			close $FH; ## no critic (InputOutput::RequireCheckedSyscalls)
			$buf = '';

			if ($totalread != $len) {
				($content, $msg) = ($content, "Content-Length does not match amount of recieved bytes.\n");
			} else {
				($status, $content, $msg) = ('201', $content, "Uploaded.\n");
			}
		} else {
			carp "[FATA] Unable to open file $name: $OS_ERROR";
			($status, $content, $msg) = ('500', $content, "Unable to write: $OS_ERROR\n");
		}
	} else {
		$msg = "Incorrect Content-Length\n";
	}

	return $status, $content, $msg;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4 :
