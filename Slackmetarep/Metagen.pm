# Most of this data is generated during package build process and being uploaded
# to pool alongside with packages themselves. So we can easily and fast regen repo meta.

# Assume that whole operation takes resonable amount of time to perform it syncronously.

# Metadata consists of
# * CHECKSUMS.md5    - md5 of each file in repo
# * CHECKSUMS.md5.gz - same as above, gzipped form
# * ChangeLog.txt    - optional, contains history of changes, this script does not handle it
# * FILELIST.TXT     - whole list of files that are part of repostory data or metadata
# * PACKAGES.TXT     - packages description with metainfo such as relative path in repo, compressed size and
#                      uncompressed size
# * PACKAGES.TXT.gz  - same as above, gzipped form
# * MANIFEST.bz2     - list of files in each package

# TODO: validate metadata

# N.B. I've got really strange behaviour if $tmpfiles keys does not end with newline char. It tends to loose ref to
#      value if hashref is arg of some sub or method. And it is nice that encode_base64 by default returns string with
#      newline char at the end

package Slackmetarep::Metagen;

use 5.018;
use warnings;
use strict;

use utf8;
use open qw (:std :utf8);
use English qw ( -no_match_vars );

use bytes ();
use Carp qw (carp cluck);
use Compress::Raw::Bzip2 qw (BZ_RUN_OK BZ_STREAM_END);
use Compress::Raw::Zlib;
use Data::Dumper;
use Fcntl qw (:DEFAULT :flock);
use File::Temp qw (mktemp tempfile);
use File::Copy qw (move);
use MIME::Base64;
use POSIX qw (strftime);

use Slackmetarep::Conf qw (LoadConf);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Metagen __mktmpfiles);

sub Metagen ($);
sub __prettyFormattedDate ();
sub __trim ($);
sub __readFile ($);
sub __dirList ($);
sub __writeFile (@);
sub __bzip2Data ($);
sub __gzipData ($);
sub __mktmpfiles ($);
sub __renametmpfiles (@);
sub __removetmpfiles ($);
sub __setlock ($);
sub __removelock (@);

my $lockfile = '.update.lock';

sub Metagen ($) {
	my $dir = shift;
	my $c = LoadConf ();

	$dir = '' . $c->{metagen}->{$dir};

	unless (defined $dir || ($dir eq '')) {
		return '400', 'text/plain', "No such repository\n";
	}

	my $lock->{filename} = sprintf '%s/%s', $dir, $lockfile;

	my $dirlist = __dirList ($dir);

	if (defined $dirlist->{error}) {
		return '500', 'text/plain', $dirlist->{error};
	}

	my @filelist = @{$dirlist->{dir}};
	$dirlist = undef;

	$lock = __setlock ($lock);
	my $tmpfiles = __mktmpfiles ($dir);

	# Generate Manifest.bz2
	my $buf = '';

	for (my $i = 0; $i <= $#filelist; $i++) {
		my $filename = $filelist[$i];

		if ($filename =~ /\.lst/xmsg) {
			my $file = __readFile ("$dir/$filename");

			if (defined $file->{'error'}) {
				__removetmpfiles ($tmpfiles);
				__removelock ($lock);
				return '500', 'text/plain', $file->{error};
			}

			$buf .= __trim $file->{data};
			$buf .= "\n\n\n";

			$file->{data} = '';
			$file = undef;
		}
	}

	my $bzippedData = __bzip2Data (\$buf);

	if (defined $bzippedData->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $bzippedData->{error};
	}

	my $manifest_bz2 = __writeFile ($tmpfiles->{encode_base64 ('MANIFEST.bz2')}->{tmpfilename}, \$bzippedData->{data});

	if (defined $manifest_bz2->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $manifest_bz2->{error};
	}

	$bzippedData->{data} = '';
	$bzippedData = undef;

	# Generate CHECKSUMS.md5 and CHECKSUMS.md5.gz
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

	for (my $i = 0; $i <= $#filelist; $i++) {
		my $filename = $filelist[$i];
		next if ($filename =~ /CHECKSUMS\.md5$/xmsg);
		next if ($filename =~ /CHECKSUMS.md5.gz$/xmsg);

		if ($filename =~ /\.md5/xmsg) {
			my $file = __readFile ("$dir/$filename");

			if (defined $file->{'error'}) {
				__removetmpfiles ($tmpfiles);
				__removelock ($lock);
				return '500', 'text/plain', $file->{error};
			}

			$buf .= $file->{data};

			$file->{data} = '';
			$file = undef;
		}
	}

	my $checksum_md5_file = __writeFile ($tmpfiles->{encode_base64 ('CHECKSUMS.md5')}->{tmpfilename}, \$buf);

	if (defined $checksum_md5_file->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $checksum_md5_file->{error};
	}

	# Gzip CHECKSUM.md5 contents
	my $gzippedBuf = __gzipData (\$buf);

	if (defined $gzippedBuf->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $gzippedBuf->{error};
	}

	$buf = '';

	my $checksum_md5_gz_file = __writeFile ($tmpfiles->{encode_base64 ('CHECKSUMS.md5.gz')}->{tmpfilename}, \$gzippedBuf->{data});

	if (defined $checksum_md5_gz_file->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $checksum_md5_gz_file->{error};
	}

	$gzippedBuf->{data} = '';
	$gzippedBuf = undef;

	# Generate PACKAGES.TXT and PACKAGES.TXT.gz
	$buf = sprintf "PACKAGES.TXT;  %s\n\n\n", __prettyFormattedDate ();

	# At this point we have no need to preserve @filelist, we rather want to empty it
	for (my $i = 0; $i <= $#filelist; $i++) {
		my $filename = $filelist[$i];

		if ($filename =~ /\.meta/xmsg) {
			my $file = __readFile ("$dir/$filename");

			if (defined $file->{'error'}) {
				__removetmpfiles ($tmpfiles);
				__removelock ($lock);
				return '500', 'text/plain', $file->{error};
			}

			$buf .= __trim ($file->{data});
			$buf .= "\n\n";

			$file->{data} = '';
			$file = undef;
		}
	}

	$#filelist = -1;

	my $ass = $tmpfiles->{encode_base64 ('PACKAGES.TXT')}->{tmpfilename};
	my $packages_txt_file = __writeFile ($ass, \$buf);

	if (defined $packages_txt_file->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $packages_txt_file->{error};
	}

	$gzippedBuf = __gzipData (\$buf);

	if (defined $gzippedBuf->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $gzippedBuf->{error};
	}

	$buf = '';

	my $packages_txt_gz_file = __writeFile ($tmpfiles->{encode_base64 ('PACKAGES.TXT.gz')}->{tmpfilename}, \$gzippedBuf->{data});

	if (defined $packages_txt_gz_file->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return ('500', 'text/plain', $packages_txt_gz_file->{error});
	}

	$gzippedBuf->{data} = '';
	$gzippedBuf = undef;

	# Generate FILELIST.TXT
	$buf = __prettyFormattedDate;
	$buf .= "\n\n";
	$buf .= << 'BUFFER';
Here is the file list for this directory,
maintained by eleksir <eleksir@gmail.com> .
If you are using a mirror site and find missing or extra files
in the subdirectories, please have the archive administrator
refresh the mirror.

BUFFER

	$dirlist = __dirList ($dir);

	if (defined $dirlist->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $dirlist->{error};
	}

	@filelist = @{$dirlist->{dir}};
	$dirlist = undef;

	for (my $i = 0; $i <= $#filelist; $i++) {
		my $filename = sprintf '%s/%s', $dir, $filelist[$i];
		my @stat = stat $filename;
		my @date = localtime $stat[10];

		$buf .= sprintf (
			"-rw-r--r-- %d root root % 8d %04d-%02d-%02d %02d:%02d ./%s\n",
			$stat[3],
			$stat[7],
			$date[5] + 1900,
			$date[4],
			$date[3],
			$date[2],
			$date[1],
			$filelist[$i]
		);
	}

	$#filelist = -1;
	my $f = $tmpfiles->{'FILELIST.TXT'};
	my $filelist = __writeFile ($tmpfiles->{encode_base64 ('FILELIST.TXT')}->{tmpfilename}, \$buf);

	if (defined $filelist->{error}) {
		__removetmpfiles ($tmpfiles);
		__removelock ($lock);
		return '500', 'text/plain', $filelist->{error};
	}

	$buf = '';

	if (__renametmpfiles ($dir, $tmpfiles)) {
		__removelock ($lock);
		return '200', 'text/plain', "Done\n";
	} else {
		__removelock ($lock);
		return '500', 'text/plain', "Metadata rename operation error\n";
	}
}

sub __prettyFormattedDate () {
	my @time = gmtime(time);
	my @DAYOFWEEK = qw(Sun Mon Tue Wed Thu Fri Sat);
	my @MONTH = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Nov Dec);
	return strftime "$DAYOFWEEK[$time[6]] $MONTH[$time[4] - 1] %e %T UTC %Y", @time;
}

sub __trim ($) {
	my $str = shift;

	while (substr ($str, 0, 1) =~ /^\s$/xms) {
		$str = substr $str, 1;
	}

	while (substr ($str, -1, 1) =~ /^\s$/xms) {
		chop $str;
	}

	return $str;
}

sub __readFile ($) {
	my $file = shift;
	my $ret;

	open (my $FILEHANDLE, '<', $file) or do {
		my $msg = "Unable to open file for reading $file: $OS_ERROR";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	};

	binmode $FILEHANDLE;
	my $buf;
	my $len = (stat $file)[7];
	my $readlen = read $FILEHANDLE, $buf, $len;
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

sub __writeFile (@) {
	my $file = shift;
	my $dataref = shift;
	my $ret;

	unless (defined $file) {
		return $ret;
	}

	sysopen (my $FILEHANDLE, $file, O_WRONLY|O_TRUNC|O_CREAT) or do {
		my $msg = "Unable to open file for writing $file: $OS_ERROR";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	};

	binmode $FILEHANDLE;

	my $len = bytes::length ${$dataref};
	use bytes;
	my $writelen = syswrite $FILEHANDLE, ${$dataref}, $len;
	no bytes;
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

sub __dirList ($) {
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

sub __bzip2Data ($) {
	my $databufref = shift;
	my $ret;
	my $bz = Compress::Raw::Bzip2->new (1, 9, 0);

	unless (defined $bz) {
		my $msg = 'Unable to create bz object';
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($bz->bzdeflate (${$databufref}, $ret->{data}) != BZ_RUN_OK) {
		my $msg = 'Unable to perofrm bzip2 compression';
		carp "[FATA] $msg";
		delete ($ret->{data});
		$ret->{error} = $msg;
		return $ret;
	}

	if ($bz->bzflush ($ret->{data}) != BZ_RUN_OK) {
		my $msg = 'Unable to flush bz buffer';
		carp "[FATA] $msg";
		delete ($ret->{data});
		$ret->{error} = $msg;
		return $ret;
	}

	if ($bz->bzclose ($ret->{data}) != BZ_STREAM_END) {
		my $msg = 'Unable to flush and close bz buffer';
		carp "[FATA] $msg";
		delete ($ret->{data});
		$ret->{error} = $msg;
		return $ret;
	}

	return $ret;
}

sub __gzipData ($) {
	my $databufref = shift;
	my $ret;

	my ($gz, $status) = Compress::Raw::Zlib::Deflate->new (
		-Level => Z_BEST_COMPRESSION,
		-WindowBits => WANT_GZIP,
		-AppendOutput => 1,
	);


	if ($status != Z_OK) {
		my $msg = "Unable to create gz object: $status";
		carp "[FATA] $msg";
		$ret->{error} = $msg;
		return $ret;
	}

	if ($gz->deflate (${$databufref}, $ret->{data}) != Z_OK) {
		my $msg = 'Unable to deflate';
		carp "[FATA] $msg";
		delete ($ret->{data});
		$ret->{error} = $msg;
		return $ret;
	}

	if ($gz->flush ($ret->{data}) != Z_OK) {
		my $msg = 'Unable to flush gz object';
		carp "[FATA] $msg";
		delete ($ret->{data});
		$ret->{error} = $msg;
		return $ret;
	}

	return $ret;
}

sub __mktmpfiles ($) {
	my $basedir = shift;
	my $file;
	my @metafiles = ('CHECKSUMS.md5', 'CHECKSUMS.md5.gz', 'MANIFEST.bz2', 'FILELIST.TXT', 'PACKAGES.TXT', 'PACKAGES.TXT.gz');

	foreach my $tmpfile (@metafiles) {
		$file->{encode_base64 ($tmpfile)}->{tmpfilename} = mktemp (sprintf ('%s/%s.XXXXXX', $basedir, $tmpfile));
		$file->{encode_base64 ($tmpfile)}->{filename} = sprintf '%s/%s', $basedir, $tmpfile;
	}

	return $file;
}

sub __renametmpfiles (@) {
	# Rename DST files to kind of temporary to be able to restore it if something goes wrong with renamning of new files
	my $dir = shift;
	my $file = shift;

	my $error = 0;
	my $origfile = __mktmpfiles ($dir);

	# Backup original metadata if it exist
	foreach my $myfile (keys %{$origfile}) {
		my $warningShown = 0;

		if (-f $origfile->{$myfile}->{filename}) {
			unless (move $origfile->{$myfile}->{filename}, $origfile->{$myfile}->{tmpfilename}) {
				unless ($warningShown) {
					carp '[WARN] If this is first run, ignore next complians about renaming, we have no metadata files yet';
					$warningShown = 1;
				}

				carp (
					sprintf (
						'[WARN] Unable to rename original metadata file %s to %s: %s',
						$origfile->{$myfile}->{filename},
						$origfile->{$myfile}->{tmpfilename},
						$OS_ERROR
					)
				);

			}
		}
	}

	# Rename our metadata file to correct names
	foreach my $myfile (keys %{$file}) {
		unless (move $file->{$myfile}->{tmpfilename}, $file->{$myfile}->{filename}) {
			carp (
				sprintf (
					'[FATA] unable to rename temporary metadata file %s to %s: %s',
					$file->{$myfile}->{tmpfilename},
					$file->{$myfile}->{filename},
					$OS_ERROR
				)
			);

			$error = 1;
#			last;
		}
	}

	# On error - remove our files, restore original metadata and return
	if ($error) {
		carp '[FATA] Trying to cleanup mess and restore original metadata files due to previous errors';

		# Remove our files
		foreach my $myfile (keys %{$file}) {
			# Remove temporary file
			if (-f $file->{$myfile}->{tmpfilename}) {
				unless (unlink $file->{$myfile}->{tmpfilename}) {
					carp (
						sprintf (
							'[ERRO] Unable to unlink %s: %s',
							$file->{$myfile}->{tmpfilename},
							$OS_ERROR
						)
					);
				}
			}

			# Remove new metadata file
			if (-f $file->{$myfile}->{filename}) {
				unless (unlink $file->{$myfile}->{filename}) {
					carp (
						sprintf (
							'[ERRO] Unable to unlink %s: %s',
							$file->{$myfile}->{filename},
							$OS_ERROR
						)
					);
				}
			}
		}

		# Restore original metadata files, if they exist
		foreach my $myfile (keys %{$origfile}) {
			if (-f $origfile->{$myfile}->{tmpfilename}) {
				unless (move $origfile->{$myfile}->{tmpfilename}, $origfile->{$myfile}->{filename}) {
					carp (
						sprintf (
							'[FATA] Unable to restore original metadata file %s from %s: %s',
							$origfile->{$myfile}->{tmpfilename},
							$origfile->{$myfile}->{filename},
							$OS_ERROR
						)
					);
				}
			} else {
				carp (
					sprintf (
						'[FATA] Unable to find backup of original metadata file %s to restore it to %s',
						$origfile->{$myfile}->{tmpfilename},
						$origfile->{$myfile}->{filename}
					)
				);
			}
		}

		return 0;
	}

	# On success drop backup of original metadata if exist, ofcorse
	foreach my $myfile (keys %{$origfile}) {
		if (-f $origfile->{$myfile}->{tmpfilename}) {
			unless (unlink $origfile->{$myfile}->{tmpfilename}) {
				# That is bad, but overall operation is successful, right?
				carp (
					sprintf (
						'[ERRO] Unable to unlink %s: %s',
						$origfile->{$myfile}->{tmpfilename},
						$OS_ERROR
					)
				);
			}
		}
	}

	return 1;
}

sub __removetmpfiles ($) {
	my $tmpfile = shift;

	unless (defined $tmpfile) {
		return ;
	}

	foreach my $filename (keys %{$tmpfile}) {
		if (-f $tmpfile->{$filename}->{tmpfilename}) {
			unless (unlink $tmpfile->{$filename}->{tmpfilename}) {
				carp (
					sprintf (
						'[ERRO] Unable to unlink %s: %s',
						$tmpfile->{$filename}->{tmpfilename},
						$OS_ERROR
					)
				);
			}
		}
	}

	return;
}

sub __setlock ($) {
	my $lock= shift;
	my $note = 1;

	unless (open $lock->{fh}, '>', $lock->{filename}) {
		carp "[ERRO] Unable to create lock-file on $lock->{filename}: $OS_ERROR";
		return undef;
	}

	unless (flock $lock->{fh}, LOCK_EX) {
		close $lock->{fh}; ## no critic (InputOutput::RequireCheckedSyscalls)
		carp "[ERRO] Unable to set lock on $lock->{filename}: $OS_ERROR";
		return undef;
	}

	return $lock;
}

sub __removelock (@) {
	my $lock = shift;

	unless (defined $lock) {
		carp '[ERRO] Unable to remove metadata lock! Looks like it does not exist! or unsupported on this fs';
		return;
	}

	unless (flock $lock->{fh}, LOCK_UN) {
		carp "[ERRO] Unable to unlock file $lock->{filename}: $OS_ERROR";
	}

	close $lock->{fh}; ## no critic (InputOutput::RequireCheckedSyscalls)

	unless (unlink $lock->{filename}) {
		carp "[ERRO] Unable to unlink lock-file $lock->{filename}: $OS_ERROR";
	}

	return;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4 :
