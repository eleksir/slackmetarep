# Most of this data is generated during package build process and being uploaded
# to pool alongside with packages themselves. So we can easily and fast regen meta.

# Assume that whole operation takes resonable amount of time to perform it syncronously

# metadata consists of
# * CHECKSUMS.md5 or CHECKSUMS.md5.gz - checksum of each file in repo
# * ChangeLog.txt - optional, contains history of changes, this script does not
#                   handle it
# * FILELIST.TXT  - whole list of files that are part of repostory data or
#                   metadata
# * PACKAGES.TXT  - packages description with metainfo such as relative path in
#                   repo, compressed size and uncompressed size
# * MANIFEST.bz2  - list of files in each package

# TODO: make metadata in atomic way
# TODO: validate metadata

package Slackmetarep::Metagen;

use warnings;
use strict;

use utf8;
use open qw(:std :utf8);
use vars qw/$VERSION/;
use English qw( -no_match_vars );

use Carp;
use Fcntl;
use Compress::Raw::Bzip2 qw(BZ_RUN_OK BZ_STREAM_END);
use Compress::Raw::Zlib;
use POSIX qw(strftime);

use Slackmetarep::Conf qw(loadConf);

use Exporter qw(import);
our @EXPORT_OK = qw(metagen);

$VERSION = '1.0';

sub metagen($);
sub __pdate;        # generates current date in pretty format
sub __trim($);
sub __readfile($);
sub __dirlist($);
sub __writefile(@);
sub __bzdata($);
sub __gzdata($);

sub metagen ($) {
	my $dir = shift;
	my $c = loadConf();
	$dir = $c->{metagen}->{$dir};

	unless (defined $dir || ($dir eq '')) {
		return ('400', 'text/plain', "No such repository\n");
	}

	my $dirlist = __dirlist ($dir);
	return ('500', 'text/plain', $dirlist->{error}) if (defined $dirlist->{error});
	my @filelist = @{$dirlist->{dir}};
	$dirlist = undef;

	# manifest
	my $buf = '';

	foreach my $filename (@filelist) {
		if ($filename =~ /\.lst/xmsg) {
			my $file = __readfile("$dir/$filename");
			return ('500', 'text/plain', $file->{error}) if (defined $file->{'error'});
			$buf .= __trim $file->{data};
			$buf .= "\n\n\n";
			$file->{data} = ''; $file = undef;
		}
	}

	my $bzdata = __bzdata (\$buf);
	return ('500', 'text/plain', $bzdata->{error}) if (defined $bzdata->{error});

	my $manifest = __writefile ("$dir/MANIFEST.bz2", \$bzdata->{data});
	return ('500', 'text/plain', $manifest->{error}) if (defined $manifest->{error});

	$bzdata->{data} = ''; $bzdata = undef;

	# checksums
	$buf = << 'MSG';
These are the MD5 message digests for the files in this directory.
If you want to test your files, use 'md5sum' and compare the values to
the ones listed here.

To test all these files, use this command:

tail +13 CHECKSUMS.md5 | md5sum --check | less

'md5sum' can be found in the GNU coreutils package on ftp.gnu.org in
/pub/gnu, or at any GNU mirror site.

MD5 message digest                Filename
MSG

	foreach my $filename (@filelist) {
		next if ($filename =~ /CHECKSUMS\.md5$/xmsg);
		next if ($filename =~ /CHECKSUMS.md5.gz$/xmsg);

		if ($filename =~ /\.md5/xmsg) {
			my $file = __readfile("$dir/$filename");
			return ('500', 'text/plain', $file->{error}) if (defined $file->{'error'});
			$buf .= $file->{data};
			$file->{data} = ''; $file = undef;
		}
	}

	my $checksum = __writefile ("$dir/CHECKSUMS.md5", \$buf);
	return ('500', 'text/plain', $checksum->{error}) if (defined $checksum->{error});

	my $gzipchecksum = __gzdata(\$buf);
	return ('500', 'text/plain', $gzipchecksum->{error}) if (defined $gzipchecksum->{error});
	$buf = '';

	my $checksumgz = __writefile ("$dir/CHECKSUMS.md5.gz", \$gzipchecksum->{data});
	return ('500', 'text/plain', $checksumgz->{error}) if (defined $checksumgz->{error});
	$gzipchecksum->{data} = ''; $gzipchecksum = undef;

	# packages
	$buf = sprintf "PACKAGES.TXT;  %s\n\n\n", __pdate;

	foreach my $filename (@filelist) {
		if ($filename =~ /\.meta/xmsg) {
			my $file = __readfile("$dir/$filename");
			return ('500', 'text/plain', $file->{error}) if (defined $file->{'error'});
			$buf .= __trim ($file->{data});
			$buf .= "\n\n";
			$file->{data} = ''; $file = undef;
		}
	}

	my $packages = __writefile ("$dir/PACKAGES.TXT", \$buf);
	return ('500', 'text/plain', $packages->{error}) if (defined $packages->{error});

	my $gzippackages = __gzdata(\$buf);
	return ('500', 'text/plain', $gzippackages->{error}) if (defined $gzippackages->{error});
	$buf = '';

	my $packagesgz = __writefile ("$dir/PACKAGES.TXT.gz", \$gzippackages->{data});
	return ('500', 'text/plain', $packagesgz->{error}) if (defined $packagesgz->{error});
	$gzippackages->{data} = ''; $gzippackages = undef;

	# filelist
	$buf = __pdate;
	$buf .= "\n\n";
	$buf .= << 'BUFFER';
Here is the file list for this directory,
maintained by eleksir <eleksir@gmail.com> .
If you are using a mirror site and find missing or extra files
in the subdirectories, please have the archive administrator
refresh the mirror.

BUFFER

	# dir listing is not actual, so we need to re-read it
	$#filelist = -1;
	$dirlist = __dirlist ($dir);
	return ('500', 'text/plain', $dirlist->{error}) if (defined $dirlist->{error});
	@filelist = @{$dirlist->{dir}};
	$dirlist = undef;

	while (my $file = shift (@filelist)) {
		my $filename = sprintf ('%s/%s', $dir, $file);
		my @stat = stat $filename;
		my @date = localtime ($stat[10]);

		$buf .= sprintf (
			"-rw-r--r-- %d root root % 8d %04d-%02d-%02d %02d:%02d ./%s\n",
			$stat[3],
			$stat[7],
			$date[5] + 1900,
			$date[4],
			$date[3],
			$date[2],
			$date[1],
			$file
		);
	}

	$#filelist = -1;
	my $filelist = __writefile ("$dir/FILELIST.TXT", \$buf);
	return ('500', 'text/plain', $filelist->{error}) if (defined $filelist->{error});
	$buf = '';
	return  ('200', 'text/plain', "Done\n");
}

sub __pdate {
	my @time = gmtime(time);
	my @DAYOFWEEK = qw(Sun Mon Tue Wed Thu Fri Sat);
	my @MONTH = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Nov Dec);
	return strftime "$DAYOFWEEK[$time[6]] $MONTH[$time[4] - 1] %e %T UTC %Y", @time;
}

sub __trim ($) {
	my $str = shift;

	while (substr ($str, 0, 1) =~ /^\s$/xms) {
		$str = substr ($str, 1);
	}

	while (substr ($str, -1, 1) =~ /^\s$/xms) {
		chop ($str);
	}

	return $str;
}

sub __readfile ($) {
	my $file = shift;
	my $ret;

	open (my $FILEHANDLE, '<', $file) or do {
		my $msg = "Unable to open file $file: $OS_ERROR";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	};

	binmode $FILEHANDLE;
	my $buf;
	my $len = (stat $file)[7];
	my $readlen = read ($FILEHANDLE, $buf, $len);
	close $FILEHANDLE; ## no critic (InputOutput::RequireCheckedSyscalls)

	unless (defined $readlen) {
		my $msg = "Unable to read $file: $OS_ERROR";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($readlen != $len) {
		my $msg = "Unable to read $file: amount of read bytes does not match with file size";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	$ret->{data} = $buf;
	return $ret;
}

sub __writefile (@) {
	my $file = shift;
	my $dataref = shift;
	my $ret;

	sysopen (my $FILEHANDLE, $file, O_WRONLY|O_TRUNC|O_CREAT) or do {
		my $msg = "Unable to open file $file: $OS_ERROR";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	};

	binmode $FILEHANDLE;

	use bytes;
	my $len = length ${$dataref};
	no bytes;
	my $writelen = syswrite ($FILEHANDLE, ${$dataref}, $len);
	close $FILEHANDLE; ## no critic (InputOutput::RequireCheckedSyscalls)

	unless (defined $writelen) {
		my $msg = "Unable to write $file: $OS_ERROR";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($writelen != $len) {
		my $msg = "Unable to write $file: amount of read bytes does not match with file size";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	$ret->{success} = 1;
	return $ret;
}

sub __dirlist ($) {
	my $dir = shift;
	my $res;
	my @files;

	opendir (my $dirhandle, $dir) or do {
		my $msg = "Unable to open $dir: $OS_ERROR";
		carp "[FATA] $msg";
		$res->{error} = $msg;
		return $msg;
	};

	while (readdir $dirhandle) {
		next unless (-f "$dir/$_");
		push @files, $_;
	}

	closedir $dirhandle;
	@files = sort @files;
	$res->{dir} = \@files;
	return $res;
}

sub __bzdata ($) {
	my $databufref = shift;
	my $ret;
	my $bzdata;
	my $bz = Compress::Raw::Bzip2->new (1, 9, 0);

	unless (defined $bz) {
		my $msg = 'Unable to create bz object';
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($bz->bzdeflate(${$databufref}, $bzdata) != BZ_RUN_OK) {
		my $msg = 'Unable to perofrm bzip2 compression';
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($bz->bzflush($bzdata) != BZ_RUN_OK) {
		my $msg = 'Unable to flush bz buffer';
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($bz->bzclose($bzdata) != BZ_STREAM_END) {
		my $msg = 'Unable to flush and close bz buffer';
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	$ret->{data} = $bzdata;
	return $ret;
}

sub __gzdata ($) {
	my $databufref = shift;
	my $ret;
	my $gzdata;

	my $gz = Compress::Raw::Zlib::Deflate->new (
		-Level => Z_BEST_COMPRESSION,
		-CRC32 => 1,
		-ADLER32=> 1,
		-WindowBits => WANT_GZIP
	);

	unless (defined $gz) {
		my $msg = 'Unable to create gz object';
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($gz->deflate(${$databufref}, $gzdata) != Z_OK) {
		my $msg = 'Unable to deflate';
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($gz->flush($gzdata) != Z_OK) {
		my $msg = 'Unable to flush gz object';
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	$ret->{data} = $gzdata;
	return $ret;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4 :
