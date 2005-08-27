#! perl
use strict;
use warnings;

# $Id: luckygoogle.pl 404 2005-08-26 12:02:05Z abeltje $

=head1 NAME

luckygoole.pl - Search google with the I<I'm Feeling Lucky> button

=head1 SYNOPSS

    C:>perl luckygoogle.pl your search string

=head1 DESCRIPTION

This program opens an IE with google (in English), fills in the words
provided on the commandline and pushes the I<I'm Feeling Lucky>
button.

=cut

use FindBin;
use lib "$FindBin::Bin/../lib";

use Win32;
use Win32::IE::Mechanize;

# Simple program to use google

my %opt = (
   url => 'http://www.google.com/search?hl=en',
);

my $q = @ARGV 
    ? join " ", map /\s/ ? qq/"$_"/ : $_ => @ARGV
    : 'InternetExplorer.Application msdn';
print "Feeling lucky for: '$q'\n";

# Show browser while filling in the search form
my $ie = Win32::IE::Mechanize->new( visible => 1, quiet => 1 ) or
    die "Cannot create an InternetExplorer.Application\n";

$ie->get( $opt{url} );

$ie->submit_form(
    form_name => 'f',
    fields    => { q => $q },
    button    => { name  => 'btnI' },
);

=head1 COPYRIGHT AND LICENSE

Copyright MMV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
