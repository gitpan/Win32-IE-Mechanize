#! /usr/bin/perl -w
use strict;

# $Id: Makefile.PL 119 2004-03-28 14:57:56Z abeltje $

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          =>'Win32::IE::Mechanize', 
    DISTNAME      => 'Win32-IE-Mechanize',
    VERSION_FROM  => "lib/Win32/IE/Mechanize.pm",
    $] >= 5.005 ? (
    AUTHOR        => 'Abe Timmerman <abeltje@cpan.org>',
    ABSTRACT_FROM => 'lib/Win32/IE/Mechanize.pm',
    ) : (),

    PREREQ_PM     => { 'Win32::OLE' => 0 },
    dist          => { COMPRESS => "gzip -9f",
                       SUFFIX   => ".gz",
                     },
);

