#! /usr/bin/perl -w
use strict;

# $Id: Makefile.PL 241 2005-08-07 10:09:12Z abeltje $

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

