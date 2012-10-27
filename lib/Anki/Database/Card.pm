package Anki::Database::Card;
use utf8::all;
use Any::Moose;

has id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has created => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;

