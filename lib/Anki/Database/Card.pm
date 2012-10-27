package Anki::Database::Card;
use utf8::all;
use Any::Moose;

has id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);
sub created { $_[0]->{id} }


no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;

