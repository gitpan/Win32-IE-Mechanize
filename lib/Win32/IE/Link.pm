package Win32::IE::Link;
use strict;
use warnings;

# $Id: Link.pm 223 2005-01-03 22:30:25Z abeltje $
use vars qw( $VERSION );
$VERSION = '0.002';

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

=head2 $link->url

Returns the url from the link.

=cut

sub url {
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
    return defined $self->{innerHTML} ? $self->innerHTML : '';
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

1;

=head1 COPYRIGHT AND LICENSE

Copyright MMIV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
