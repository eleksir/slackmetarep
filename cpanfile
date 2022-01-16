## no critic (Modules::RequireVersionVar,Modules::RequireExplicitPackage,Modules::RequireEndWithOne)
## no critic (TestingAndDebugging::RequireUseStrict,TestingAndDebugging::RequireUseWarnings)
requires 'Compress::Raw::Bzip2', '==2.068';
requires 'Compress::Raw::Zlib',  '==2.068';
requires 'Exporter',             '==5.72';
requires 'Fcntl',                '==1.13';
requires 'File::Copy',           '==2.30';
requires 'File::Temp',           '==0.2304';
requires 'JSON::XS',             '==4.03';
requires 'POSIX',                '==1.53_01';
requires 'Plack',                '==1.0047';
# is a part of Plack distribution, unversioned
requires 'Plack::Util',          '0';
requires 'local::lib',           '==2.000024';
