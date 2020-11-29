# Metadata of slackware packages repository

To install packages from repository, repository package list is required. Also description is desired. All this infrmation called metadata.

## Standard metadata format

Metadata from DVD and in official repo in internet both identical. Format od data by itself allows some variations.

Metadata is split across some files for ease of it creation and parsing.

### list of metadata files in main repo

**CHECKSUMS.md5, CHECKSUMS.md5.asc, ChangeLog.txt, FILELIST.TXT, GPG-KEY, PACKAGES.TXT**

### List of metadata files in sub-repos

There are sub-repositories in main repository pool, it just sub-dirs here with its own pack of metadata files. It is: patches, pasture, extra.

**Patches** - updates.

**Pasture** - obsoleted packages that have compatibility issues, not supported by authors or for other reasons are not included in main packages list.

**Extra** - new or alternative packages that for some reasons not in main package list.

Sub-repository **patches** exist only in release version of distro. There is no patches in -current.

There is different metadata files in sub-repo:
**CHECKSUMS.md5, CHECKSUMS.md5.asc, FILE_LIST, MANIFEST.bz2, PACKAGES.TXT.**

### Metadata description

#### CHECKSUMS.md5

This is md5-checksim for each file in repository available at the moment of CHECKSUM.m5 creation. Header of this file contains instruction how check yoour copy intergity:

```text
These are the MD5 message digests for the files in this directory.
If you want to test your files, use 'md5sum' and compare the values to
the ones listed here.

To test all these files, use this command:

tail +13 CHECKSUMS.md5 | md5sum -c --quiet - | less

'md5sum' can be found in the GNU coreutils package on ftp.gnu.org in
/pub/gnu, or at any GNU mirror site.

MD5 message digest                Filename
```

There is 1 extra new line between header and actual data. There is no enpty lines in the body of this file.

```text
2c4180b57c277ad3cd38865a466a4c15  ./ANNOUNCE.14_2
85891676a985eb6c87170083e1df75de  ./CHANGES_AND_HINTS.TXT
```

and so on for all other files. Important checksums here is only for packages itselves, accompanying .txt and respective asc files. MD5 for other files can be ommited.

***Notes to format of this file:***

* first, no empty lined allowed in data body
* second, there must be exactly one newline after last record in file
* thrird, file name always begins with "./" (no quotes).

#### CHECKSUMS.md5.asc

This file sries gpg signature for CHECKSUMS.md5.

GPG signature is highly desired but not required. It ensures that packages with matching md5 is authored and placed to repository by owner of closed part of gpg key. In other word it ensures that package is genuine.

#### ChangeLog.txt

All package changes are stored in this file. This file exist in main repo and contains also changes that made to sub-repostory.

Changes are recorded here in "batches":

```text
Sat Nov  2 18:52:12 UTC 2019
a/aaa_terminfo-6.1_20191026-x86_64-1.txz:  Upgraded.
a/cryptsetup-2.2.2-x86_64-1.txz:  Upgraded.
a/lvm2-2.03.06-x86_64-1.txz:  Upgraded.
d/Cython-0.29.14-x86_64-1.txz:  Upgraded.
l/ncurses-6.1_20191026-x86_64-1.txz:  Upgraded.
  Restore the --without-normal option to skip static libraries as used in 14.2.
  Thanks to Richard Narron.
x/xterm-349-x86_64-2.txz:  Rebuilt.
  In /etc/app-defaults/XTerm, use terminus-medium instead of terminus-bold.
  Thanks to igadoter.
+--------------------------+
```

Note the delimeter at the bottom of the batch.
This file is optional and can be found not only in official repo but for example in AlienBob's. By the way in AlienBob's reop this file also *begins* with delimeter and contains extra newline between batches.

#### FILELIST.TXT

List of all files in repository. Means all related files for endusers, but as a rule it contains all files in repository.

Thist file contains header:

```text
Sat Nov  2 19:03:12 UTC 2019

Here is the file list for this directory.  If you are using a
mirror site and find missing or extra files in the disk
subdirectories, please have the archive administrator refresh
the mirror.

```

Note the date of file generation and one extra new line after header.

File body looks like that:

```text
drwxr-xr-x 12 root root      4096 2019-11-02 18:52 .
-rw-r--r--  1 root root     10064 2016-06-30 18:39 ./ANNOUNCE.14_2
-rw-r--r--  1 root root     14642 2019-10-18 21:18 ./CHANGES_AND_HINTS.TXT
```

Similar listing you can get by invoking next command:

```bash
ls -lAn --time-style=long-iso "$dir"
```

but please note that in ls output there is no "." directory and file path will not begin with "./" which is required.

File must end with newline symbol.

#### GPG-KEY

This is public part of GPG-key you can check integrity of files that is signed with apropiate closed key (files with satelite files with **.asc** extension).

How to use it:

Check the key for correctness:

```bash
gpg --keyid-format long --show-key GPG-KEY
```

Import it to our keyring:

```bash
gpg --import GPG-KEY
```

Then check:

```bash
gpg --verify CHECKSUMS.md5.asc CHECKSUMS.md5
```

#### PACKAGES.TXT

Repository packages list (kind of). Classic header looks like this:

```text

PACKAGES.TXT;  Sat Nov  2 19:01:20 UTC 2019

This file provides details on the Slackware packages found
in the ./slackware64/ directory.

Total size of all packages (compressed):  2612 MB
Total size of all packages (uncompressed):  11323 MB


```

Header begins with newline and ends with 2 newlines.

Technically whole header can be "compressed" to this form withoun any loss:

```text
PACKAGES.TXT;  Sun Nov  3 12:47:53 UTC 2019

```

In this particular case file does not begin with newline and contains only one newline in the end of header. AlienBob do it like this.

Body itself consists of batches of strings related to each package. Batch separator is extra newline. Example of package record from official repository:

```text
PACKAGE NAME:  ConsoleKit2-1.0.0-x86_64-4.txz
PACKAGE LOCATION:  ./slackware64/l
PACKAGE SIZE (compressed):  148 K
PACKAGE SIZE (uncompressed):  780 K
PACKAGE DESCRIPTION:
ConsoleKit2: ConsoleKit2 (user, login, and seat tracking framework)
ConsoleKit2:
ConsoleKit2: ConsoleKit2 is a framework for defining and tracking users, login
ConsoleKit2: sessions, and seats.
ConsoleKit2:
ConsoleKit2: Homepage: https://github.com/ConsoleKit2/ConsoleKit2
ConsoleKit2:
```

Example from thrird-party repo:

```text
PACKAGE NAME:  SDL2-2.0.10-x86_64-1.txz
PACKAGE LOCATION:  .
PACKAGE SIZE (compressed):  609 K
PACKAGE SIZE (uncompressed):  3260 K
PACKAGE REQUIRED:  
PACKAGE CONFLICTS:  
PACKAGE SUGGESTS:  
PACKAGE DESCRIPTION:
SDL2:
SDL2: Simple DirectMedia Layer is a cross-platform development library
SDL2: designed to provide low-level access to audio, keyboard, mouse,
SDL2: joystick, and graphics hardware ia via OpenGL. It is used by
SDL2: video playback software, emulators, and games.
SDL2:
SDL2: Homepage: http://www.libsdl.org
SDL2:
SDL2:
SDL2:
```

As you can see everythin that goes after "PACKAGE DESCRIPTION:" is contents of apropriate slack-desc from package.

Also thrird party repository contains extended metainformation - dependencies, conflicts and recommended packages.

In official repository this file ends with 2 newlines, AlienBob makes only one and it works fine.

#### MANIFEST.bz2

In official repository it is placed only in sub-repositries, for thrird-parties it placed in main repository.

It doesen't contain any header. All records are separated by extra 2 newlines. File ends with 2 extra newlines.

Example of one record:

```text
++========================================
||
||   Package:  ./aspell-word-lists/aspell-am-0.03_1-x86_64-5.txz
||
++========================================
drwxr-xr-x root/root         0 2016-06-06 15:13 ./
drwxr-xr-x root/root         0 2016-06-06 15:13 install/
-rw-r--r-- root/root       190 2016-06-06 15:13 install/slack-desc
drwxr-xr-x root/root         0 2016-06-06 15:13 usr/
drwxr-xr-x root/root         0 2016-06-06 15:13 usr/lib64/
drwxr-xr-x root/root         0 2016-06-06 15:13 usr/lib64/aspell/
-rw-r--r-- root/root       101 2016-06-06 15:13 usr/lib64/aspell/am.dat
-rw-r--r-- root/root    282544 2016-06-06 15:13 usr/lib64/aspell/am.rws
-rw-r--r-- root/root       426 2016-06-06 15:13 usr/lib64/aspell/am_affix.dat
-rw-r--r-- root/root      1871 2016-06-06 15:13 usr/lib64/aspell/am_phonet.dat
-rw-r--r-- root/root        72 2016-06-06 15:13 usr/lib64/aspell/amharic.alias
-rw-r--r-- root/root     25615 2016-06-06 15:13 usr/lib64/aspell/s-ethi.cmap
-rw-r--r-- root/root        70 2016-06-06 15:13 usr/lib64/aspell/am.multi
-rw-r--r-- root/root     13356 2016-06-06 15:13 usr/lib64/aspell/s-ethi.cset
drwxr-xr-x root/root         0 2016-06-06 15:13 usr/doc/
drwxr-xr-x root/root         0 2016-06-06 15:13 usr/doc/aspell-am-0.03_1/
-rw-r--r-- root/root       394 2004-12-22 20:27 usr/doc/aspell-am-0.03_1/Copyright
-rw-r--r-- root/root      2434 2004-12-28 08:15 usr/doc/aspell-am-0.03_1/README
```

## Metadata format extensions

As extension to official repo it may note existance of gzipped files: CHECKSUMS.md5.gz ChangeLog.txt.gz PACKAGES.TXT.gz. In case of gpg signature of uncompressed files exist, it also must me generated for compressed files too.

There is additional fields in PACKAGES.TXT:

```text
PACKAGE REQUIRED:  
PACKAGE CONFLICTS:  
PACKAGE SUGGESTS:  
```

Their purpos is obviously more flexible package management.

## Methods of repo metsdata creation

There is to approaches to metadata generation:

* lazy - made with pre-generated additional information chunks (or database) that are gathered durin package build process.
* full - extract all metadata directly from packages.

### Lazy method

It been used by AlienBob in his repo. Some additional files being generated during package build process and being uploaded to repository. When repository metadata generator run, it parses these additional files and makes metadata for repo.

It is also possible to store additional metainformation abaout packages in some sort of database for same puposes.

There is some benefits in this approach. It is faster to parse pre-generated metadata than extract it from package. it is especially notable on large repositories.

As a side effect there are some extra files in repository. But you can mitigate it by using database, but it adds some complexity to solution of repo metadata problem.

### Full data methos

I do not know application area of this method. But official repositories does not contain any extra files.

This method suits for small repositories.

Tradeoffs of this method is cpu and disk intensive process of metadata generation because of package unpacking and inspection occurs during metadata generation.

Benefits is obvious. You need no extra files in repo, just packages itselves.
