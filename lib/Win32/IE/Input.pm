package Win32::IE::Input;
use strict;
use warnings;

# $Id: Input.pm 372 2005-08-07 15:43:58Z abeltje $
use vars qw( $VERSION );
$VERSION = '0.003';

=head1 NAME

Win32::IE::Input - A small class to interface with the IE input objects.

=head1 SYNOPSIS

    use Win32::OLE;
    use Win32::IE::Form;

    my $agent = Win32::OLE->new( 'InternetExplorer.Application' );
    $agent->Navigate( $uri );

    # extract the images and wrap them as Win32::IE::Image
    my $doc = $agent->Document;
    my @forms;
    for ( my $i=0; $i < $doc->forms->lenght; $i++ ) {
        push @forms, Win32::IE::Form->new( $doc->forms( $i ) );
    }

    # print the information from the forms:
    foreach my $form ( @forms ) {
        printf "%s as %s\n", $form->action, $img->name||"";
    }

=head1 DESCRIPTION

The C<Win32::IE::Input> object is a thin wrapper around the DOM-objects
supplied by the InternetExplorer.Application. It is implemented as a
blessed reference to the Win32::OLE-DOM object.

=head1 METHODS

=head2 Win32::IE::Input->new( $ie_input )

Initialize a new object (like L<Win32::IE::Form>).

=cut

sub new {
    my $class = shift;

    bless \(my $self = shift), $class;
}

=head2 $input->name

Return the input-control name.

=cut

sub name { return ${ $_[0] }->name; }

=head2 $input->type

Return the type of the input control.

=cut

sub type { return lc ${ $_[0] }->type; }

=head2 $input->value( [$value] )

Get/Set the value of the input control.

=cut

sub value {
    my $self = shift;
    my $input = $$self;

    $self->type =~ /^select/i and return $self->select_value( @_ );
    $self->type =~ /^radio/i  and return $self->radio_value( @_ );

    $input->{value} = shift if @_ && defined $_[0];
    return $input->{value};
}

=head2 $input->select_value( [$value] )

Mark all options from the options collection with C<$value> as
selected and unselect all other options.

=cut

sub select_value {
    my $self = shift;
    my $input = $$self;

    my %vals;
    if ( @_ ) {
        my @values = @_;
        if ( @values == 1 && ref $values[0] eq 'HASH' ) {
            my @ords = ref $values[0]->{n}
                ? @{ $values[0]->{n} } : $values[0]->{n};
            @values = ();
            foreach my $i ( @ords ) {
                $i > 0 && $i <= $input->options->{length} and
                    push @values, $input->options( $i - 1 )->{value};
            }
        }
        @values = @{ $values[0] } if @values == 1 && ref $values[0];

        # Make sure only the last value is set for:
        # select-one type with multiple values;
        @values = ( $values[-1] ) if lc( $input->type ) eq 'select-one';
 
        %vals = map { ( $_ => undef ) } @values;

        for ( my $i = 0; $i < $input->options->{length}; $i++ ) {
            $input->options( $i )->{selected} = 
                exists $vals{ $input->options( $i )->{value} };
        }
    } else {
        for ( my $i = 0; $i < $input->options->{length}; $i++ ) {
            $input->options( $i )->{selected} and
                $vals{ $input->options( $i )->{value} } = 1;
        }
    }
    return keys %vals;
}

=head2 $input->radio_value( [$value] )

Locate all radio-buttons with the same name within this form. Now
uncheck all values that are not equal to C<$value>.

=cut

sub radio_value {
    my $self = shift;
    my $input = $$self;

    my $form = Win32::IE::Form->new( $input->form );
    my @radios = $form->_radio_group( $self->name );

    if ( @_ ) {
        my $value = shift;
        $_->{checked} = ($_->value eq $value)||0 for @radios;
    }
    my( $value ) = map $_->{value} => grep $_->checked => @radios;
    return $value;
}

=head2 $input->click

Calls the C<click()> method on the actual object. This may not work.

=cut

sub click { ${ $_[0] }->click }

=head1 COPYRIGHT AND LICENSE

Copyright MMIV, Abe Timmerman <abeltje@cpan.org>. All rights reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
