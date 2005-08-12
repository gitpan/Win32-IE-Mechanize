#! /usr/bin/perl -w
use strict;

# $Id: Makefile.PL 381 2005-08-12 10:15:14Z abeltje $

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          =>'Win32::IE::Mechanize', 
    DISTNAME      => 'Win32-IE-Mechanize',
    VERSION_FROM  => "lib/Win32/IE/Mechanize.pm",
    $] >= 5.005 ? (
    AUTHOR        => 'Abe Timmerman <abeltje@cpan.org>',
    ABSTRACT_FROM => 'lib/Win32/IE/Mechanize.pm',
    ) : (),

    PREREQ_PM     => { 'Win32::OLE' => 0, 'URI' => 0 },
    dist          => { COMPRESS => "gzip -9f",
                       SUFFIX   => ".gz",
                     },
);

use Win32;
my( undef, $maj, $min ) = Win32::GetOSVersion();
my( $os ) = Win32::GetOSName();
if ( $os =~ /^Win/ && $maj == 5 && $min > 0 ) {
    warn <<__NOTE__;
NOTE: On $os you will need to enable active local content to run the test-suite.
\tTools>Internet Options>Advanced>Security
\tTick the box: Allow active content to run in files on My Computer
__NOTE__
}
