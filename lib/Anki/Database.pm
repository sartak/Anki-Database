package Anki::Database;
use utf8::all;
use Any::Moose;
use DBI;
use HTML::Entities;
# ABSTRACT: interact with your Anki (ankisrs.net) database

use Anki::Database::Field;
use Anki::Database::Note;

has file => (
    is       => 'ro',
    isa      => 'Str',
    default  => sub { $ENV{ANKI2_DECK} },
);

has dbh => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $dbh = DBI->connect("dbi:SQLite:dbname=" . shift->file);
        $dbh->{sqlite_unicode} = 1;
        $dbh
    },
    handles => ['prepare', 'do'],
);

sub each_field {
    my ($self, $cb) = @_;
    my $sth = $self->prepare('
        SELECT id, flds FROM notes
    ;');
    $sth->execute;

    while (my ($note_id, $fields) = $sth->fetchrow_array) {
        for my $value (split "\x1f", $fields) {
            my $field = Anki::Database::Field->new(
                note_id => $note_id,
                value   => decode_entities($value),
            );

            $cb->($field);
        }
    }
}

sub each_note {
    my ($self, $cb) = @_;
    my $sth = $self->prepare('
        SELECT id, tags FROM notes
    ;');
    $sth->execute;

    while (my ($id, $tags) = $sth->fetchrow_array) {
        my $note = Anki::Database::Note->new(
            id   => $id,
            tags => [split ' ', $tags],
        );

        $cb->($note);
    }
}


no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;

