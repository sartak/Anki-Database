package Anki::Database::Field;
use utf8::all;
use Any::Moose;

has note_id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has value => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;

