package Win32::IE::Image;
use strict;
use warnings;

# $Id: Image.pm 233 2005-01-09 19:09:55Z abeltje $
use vars qw( $VERSION );
$VERSION = '0.002';

=head1 NAME Win32::IE::Image

Win32::IE::Image - Mimic L<WWW::Mechanize::Image>

=head1 SYNOPSIS

    use Win32::OLE;
    use Win32::IE::Image;

    my $agent = Win32::OLE->new( 'InternetExplorer.Application' );
    $agent->Navigate( $uri );

    # extract the images and wrap them as Win32::IE::Image
    my $doc = $agent->Document;
    my @images;
    for ( my $i=0; $i < $doc->images->lenght; $i++ ) {
        push @images, Win32::IE::Image->new( $doc->images( $i ) );
    }

    # print the information from the images:
    foreach my $img ( @images ) {
        printf "%s as %s\n", $img->url, $img->alt||"";
    }

=head1 DESCRIPTION

The C<Win32::IE::Image> object is a thin wrapper around the DOM-object
supplied by the InternetExplorer.Application. It is implemented as a
blessed reference to the Win32::OLE-DOM object.

=head1 METHODS

=head2 Win32::IE::Image->new( $element )

Create a new object, that implements url, base, tag, height, width,
alt and name

=cut

sub new {
    my $class = shift;

    bless \( my $self = shift ), $class;
}

=head2 $image->url

Return the SRC attribute from the IMG tag.

=cut

sub url {
    my $self = ${ $_[0] };
    return $self->{SRC};
}

=head2 $image->tag

Return 'IMG' for images.

=cut

sub tag {
    my $self = ${ $_[0] };
    return $self->{TAGNAME};
}

=head2 $image->width

Return the value C<width> attrubite.

=cut

sub width {
    my $self = ${ $_[0] };
    return $self->{WIDTH};
}

=head2 $image->height

Return the value C<height> attrubite.

=cut

sub height {
    my $self = ${ $_[0] };
    return $self->{HEIGHT};
}

=head2 $image->alt

Return the value C<alt> attrubite.

=cut

sub alt {
    my $self = ${ $_[0] };
    return $self->{ALT};
}

=head1 COPYRIGHT AND LICENSE

Copyright MMIV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
