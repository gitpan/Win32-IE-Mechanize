package Win32::IE::Link;
use strict;
use warnings;

# $Id: Link.pm 401 2005-08-26 11:55:50Z abeltje $
use vars qw( $VERSION );
$VERSION = '0.005';

=head1 NAME Win32::IE::Link

Win32::IE::Link - Mimic WWW::Mechanize::Link

=head1 SYNOPSIS

    use Win32::OLE;
    use Win32::IE::Link;

    my $agent = Win32::OLE->new( 'InternetExplorer.Application' );
    $agent->Navigate( $uri );

    # extract the links and wrap them as Win32::IE::Link
    my $doc = $agent->Document;
    my @links;
    for ( my $i=0; $i < $doc->anchors->lenght; $i++ ) {
        push @links, Win32::IE::Link->new( $doc->anchors( $i ) );
    }

    # print the information from the links:
    foreach my $link ( @links ) {
        printf "%s as %s\n", $link->url, $link->text||"";
    }

=head1 DESCRIPTION

The C<Win32::IE::Link> object is a thin wrapper around the DOM-object
supplied by the InternetExplorer.Application. It is implemented as a
blessed reference to the Win32::OLE-DOM object.

=head1 METHODS

=head2 Win32::IE::Link->new( $element )

C<$element> is Win32::OLE object with a C<tagName()> of B<IFRAME>,
B<FRAME>, <AREA> or <A>.

B<Note>: Although it supports the same methods as
C<L<WWW::Mechanize::Link>> it is a completely different
implementation.

=cut

sub new {
    my $class = shift;

    bless \( my $self = shift ), $class;
}

=head2 $link->attrs

Returns hash ref of all the attributes and attribute values in the tag.

=cut

sub attrs {
    my $self = ${ $_[0] };

    my $attrs = { };
    for ( my $ i = 0; $i < $self->attributes->length; $i++ ) {
        my $attr = $self->attributes( $i );
        $attrs->{ $attr->nodeName } = $attr->nodeValue;
    }

    return $attrs;
}

=head2 $link->url

Returns the url from the link.

B<NOTE>: The IE automation object only shows the interpreted results
in the attributs collection, so url() and url_abs() will be the same.

=cut

sub url {
    my $self = $_[0];
    my $link = $$self;

    my $attrs = $self->attrs;
    if ( $link->{tagName} =~ /^I?FRAME$/ ) {
        return defined $attrs->{src} ? $attrs->{src} : $link->{src};
    } else {
        return defined $attrs->{href} ? $attrs->{href} : $link->{href};
    }
}

=head2 $link->url_abs

Returns the url from the link.

=cut

sub url_abs {
    my $self = ${ $_[0] };

    if ( $self->{tagName} =~ /^I?FRAME$/ ) {
        return $self->{src};
    } else {
        return $self->{href};
    }
}

=head2 $link->text

Text of the link.

=cut

sub text {
    my $self = ${ $_[0] };
    return defined $self->{innerText}
        ? $self->{innerText}
        : defined $self->{innerHTML} ? $self->innerHTML : '';
}

=head2 $link->name

NAME attribute from the source tag, if any.

=cut

sub name {
    my $self = ${ $_[0] };
    return scalar( grep lc( $_ ) eq 'name' => keys %$self )
        ? defined $self->{name} ? $self->{name} : '' : '';
}

=head2 $link->tag

Tag name (either "A", "AREA", "FRAME" or "IFRAME").

=cut

sub tag {
    my $self = ${ $_[0] };
    return $self->{tagName};
}

=head2 $link->click

The IE link object supports its own click() method, so make it available.

=cut

sub click {
    my $self = ${ $_[0] };
    $self->fireEvent( 'onclick' );
}

1;

=head1 COPYRIGHT AND LICENSE

Copyright MMIV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
