#!/usr/bin/perl

use 5.018;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use English qw( -no_match_vars );
use JSON::XS;
use lib qw(./vendor_perl ./vendor_perl/lib/perl5);

use Slackmetarep::Conf;

use version; our $VERSION = qv(1.0);

my $CONF = loadConf();
my $j = JSON::XS->new->pretty->canonical->indent(1);
say $j->encode ($CONF);                              ## no critic (InputOutput::RequireCheckedSyscalls)

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
