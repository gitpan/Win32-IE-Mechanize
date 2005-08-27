#! perl
use strict;
use warnings;
$|++;

# $Id: weather.pl 397 2005-08-26 12:02:05Z abeltje $

=head1 NAME

weather.pl - Show the weather forecast for a city

=head1 SYNOPSS

    C:>perl weather.pl netherlands "den helder"

=head1 DESCRIPTION

This program opens an IE with L<http://www.worldweather.org> and tries
to find the country and city specified to show the current weather
forecast.

It does try to do "fuzzy matching" with soundex if no direct match is found.

=cut

use FindBin;
use lib "$FindBin::Bin/../lib";

use Win32;
use Win32::IE::Mechanize;

# Simple program that shows the weather in Amsterdam/Netherlands

my %opt = (
   url => 'http://www.worldweather.org/',
);

my( $country, $city ) = @ARGV;

# Hide the browser while loading
my $ie = Win32::IE::Mechanize->new( visible => 0 ) or
    die "Cannot create an InternetExplorer.Application\n";
local $SIG{INT} = sub { $ie->close; exit };

print "Going to go to 'worldweather.org'";
$ie->get( $opt{url} );
print " done.\n";

defined $country && length( $country ) or
    ( $country, $city ) = ( pick_country( $ie ), undef );
my $shc = defined $city && length $city ? "$city, " : "";
print "\tSearching for the weather in $shc$country\n";

if ( my( $ll ) = find_country( $ie, $country ) ) {
    printf "\tFound country like qr/\Q$country\E/i (%s)", $ll->{text};
    $ie->get( $ll->{url} );
    print " loaded\n";
    my $go_city = $ie->uri =~ m!/(\d+)/m\1\.htm$!;
    $go_city && ! defined $city and $city = pick_city( $ie );
    if ( $go_city && defined $city && length $city ) {
        if ( my( $lc ) = find_place( $ie, $city ) ) {
            printf "\tFound city like qr/\Q$city\E/i (%s)", $lc->text;
            $ie->get( $lc->url );
            print " loaded\n";
        } else {
            print "\tNo city like qr/\Q$city\E/i found\n";
        }
    } else {
        $ie->uri =~ m!/\d+/c\d+\.htm$! or
            print "\tNo city specified, select one\n";
    }
} else {
    print "\tNo coutry like qr/\Q$country\E/i found\n";
}

# Now show the wanted page
$ie->set_property( visible => 1 );

print "You must close IE yourself!";

=head1 SUBS

=cut

use Text::Soundex;

=head2 find_place( $a, $c )

Make an effort to find a link and return the link-object or undef.

If we do not find a "direct hit", use soundex() to try harder. Return
the first soundex match.

=cut

sub find_place {
    my( $a, $c ) = @_;

    my( $cl ) = $a->find_link( text_regex => qr/\Q$c\E/i );
    $cl and return $cl;

    # now make an effort
    my @links = $a->links;
    my $csx = soundex $c;
    for my $link ( $a->links ) {
        next unless $link->text;
        $csx eq soundex $link->text and return $link;
    }
    return;
}

=head2 find_country( $a, $c )

Find a country in the selectbox and return the value of the option.

=cut

sub find_country {
    my( $a, $c ) = @_;

    # We use the OLE select-object to get to the options
    # wich are presented as the options() collection
    my $form = $a->form_name( 'countryform' );
    my $select = $form->find_input( 'country', 'select' );

    # do not use the first option!
    for ( my $i = 1; $i < $$select->options->length; $i++ ) {
        my $opt = $$select->options( $i ) or next;
        $opt->innerText =~ qr/\Q$c\E/i and return {
            text => $opt->innerText,
            url  => $opt->value,
        };
    }

    # Use the soundex thing; do not use the first option!
    my $csx = soundex $c;
    for ( my $i = 1; $i < $$select->options->length; $i++ ) {
        my $opt = $$select->options( $i ) or next;
        $csx eq soundex $opt->innerText and return {
            text => $opt->innerText,
            url  => $opt->value,
        };
    }
    return;
}
=head2 pick_country( $a )

Try to pick a country from the list in the select-box.

=cut

sub pick_country {
    my( $a ) = @_;

    print "\tPick country from a list of ";
    # We use the OLE select-object to get to the options
    # wich are presented as the options() collection
    my $form = $a->form_name( 'countryform' );
    my $select = $form->find_input( 'country', 'select' );

    # Do not pick the first item
    my $cnt = $$select->options->length - 1;
    print "$cnt\n";
    my $opt = $$select->options( int( rand $cnt ) + 1 );
    return $opt->innerText;
}

=head2 pick_city( $a )

randomly pick a link from the page...

=cut

sub pick_city {
    my( $a ) = @_;

    print "\tPick city from a list of";
    my $seen_main = 0;

    # We only want links after the main page link
    # so we cannot use $a->find_link( url_regex => qr|c\d+\.htm$| );
    my @links = grep {
        $_->text =~ /back to main page/i and $seen_main++;
        $seen_main && $_->url =~ m!\d+/c\d+\.htm$!i;
    } $a->links;

    printf "%s\n", scalar @links;

    return $links[ rand $#links ]->text;
}

=head1 COPYRIGHT AND LICENSE

Copyright MMV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
