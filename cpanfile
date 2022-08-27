## no critic (Modules::RequireVersionVar,Modules::RequireExplicitPackage,Modules::RequireEndWithOne)
## no critic (TestingAndDebugging::RequireUseStrict,TestingAndDebugging::RequireUseWarnings)
# part of perl
requires 'bytes',                '0';
# part of perl, but it is dual-life module
requires 'Compress::Raw::Bzip2', '==2.201';
# part of perl, but it is dual-life module
requires 'Compress::Raw::Zlib',  '==2.201';
# part pf perl, but it is dual-life module
requires 'Exporter',             '==5.74';
# part of perl
requires 'Fcntl',                '0';
# part of perl
requires 'File::Copy',           '0';
# part of perl, but it is dual-life module
requires 'File::Temp',           '==0.2311';
requires 'JSON::XS',             '==4.03';
# part of perl
requires 'POSIX',                '0';
requires 'Plack',                '==1.0047';
# is a part of Plack distribution, unversioned
requires 'Plack::Util',          '0';
requires 'local::lib',           '==2.000024';
