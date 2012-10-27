package Anki::Database;
use utf8::all;
use Any::Moose;
use DBI;
use HTML::Entities;
use JSON ();
# ABSTRACT: interact with your Anki (ankisrs.net) database

use Anki::Database::Field;
use Anki::Database::Note;
use Anki::Database::Card;
use Anki::Database::Model;

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

has models => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my %models;
        my $sth = shift->prepare('
            SELECT models FROM col
        ;');
        $sth->execute;

        while (my ($models_json) = $sth->fetchrow_array) {
            my $raw_models = JSON::decode_json($models_json);
            for my $model_id (keys %$raw_models) {
                my $details = $raw_models->{$model_id};
                my ($name) = $details->{name} =~ /^(.*) \(.*\)$/;
                $name ||= $details->{name};

                $models{$model_id} = Anki::Database::Model->new(
                    id   => $model_id,
                    name => $name,
                );
            }
        }

        return \%models;
    },
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

    my $models = $self->models;

    my $sth = $self->prepare('
        SELECT id, tags, mid FROM notes
    ;');
    $sth->execute;

    while (my ($id, $tags, $mid) = $sth->fetchrow_array) {
        my $note = Anki::Database::Note->new(
            id    => $id,
            model => $models->{$mid},
            tags  => [split ' ', $tags],
        );

        $cb->($note);
    }
}

sub each_card {
    my ($self, $cb) = @_;

    my $sth = $self->prepare('
        SELECT id FROM cards
    ;');
    $sth->execute;

    while (my ($id) = $sth->fetchrow_array) {
        my $card = Anki::Database::Card->new(
            id => $id,
        );

        $cb->($card);
    }
}


no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;

