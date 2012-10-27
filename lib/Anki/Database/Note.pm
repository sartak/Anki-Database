package Anki::Database::Note;
use utf8::all;
use Any::Moose;

use Anki::Database::Model;

with (
    'Anki::Database::WithTags',
);

has id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has model => (
    is       => 'ro',
    isa      => 'Anki::Database::Model',
    required => 1,
);

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;

