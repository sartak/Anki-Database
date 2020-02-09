package Anki::Database;
use utf8::all;
use List::Util 'first';
use List::MoreUtils 'any';
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
        my $dbh = DBI->connect("dbi:SQLite:dbname=" . shift->file, undef, undef, {
            RaiseError => 1,
        });
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
            SELECT models
                FROM col
        ;');
        $sth->execute;

        while (my ($models_json) = $sth->fetchrow_array) {
            my $raw_models = JSON::decode_json($models_json);
            for my $model_id (keys %$raw_models) {
                my $details = $raw_models->{$model_id};
                my ($name) = $details->{name} =~ /^(.*) \(.*\)$/;
                $name ||= $details->{name};

                $models{$model_id} = Anki::Database::Model->new(
                    id        => $model_id,
                    name      => $name,
                    fields    => [ map { $_->{name} } @{ $details->{flds} } ],
                    templates => [ map { $_->{name} } @{ $details->{tmpls} } ],
                );
            }
        }

        return \%models;
    },
);

has decks => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my %decks;
        my $sth = shift->prepare('
            SELECT decks
                FROM col
        ;');
        $sth->execute;

        while (my ($decks_json) = $sth->fetchrow_array) {
            my $raw_decks = JSON::decode_json($decks_json);
            for my $deck_id (keys %$raw_decks) {
                $decks{$deck_id} = $raw_decks->{$deck_id};
            }
        }

        return \%decks;
    },
);

sub models_with_field {
    my ($self, $field) = @_;
    my @models;

    for my $model (values %{ $self->models }) {
        if (any { $_ eq $field } @{ $model->fields }) {
            push @models, $model;
        }
    }

    return @models;
}

sub model_named {
    my ($self, $name) = @_;

    return first { $_->name eq $name } values %{ $self->models };
}

sub each_field {
    my ($self, $cb) = @_;

    my $models = $self->models;

    my $sth = $self->prepare('
        SELECT id, flds, mid
            FROM notes
    ;');
    $sth->execute;

    while (my ($note_id, $fields, $model_id) = $sth->fetchrow_array) {
        my $field_names = $models->{$model_id}->{fields};
        my $i = 0;
        for my $value (split "\x1f", $fields) {
            my $field = Anki::Database::Field->new(
                note_id => $note_id,
                name    => $field_names->[$i++],
                value   => decode_entities($value),
            );

            $cb->($field);
        }
    }
}

sub each_note {
    my ($self, $cb, @desired_models) = @_;

    my %is_desired = map { $_ => 1 } @desired_models;
    my $models = $self->models;
    my @mids = map { $_->id } grep { $is_desired{$_->name} } values %$models;

    confess("Mismatch in models: wanted @desired_models, got @mids") if @desired_models != @mids;

    my $query = '
        SELECT id, tags, flds, mid
            FROM notes
    ';
    if (@mids) {
        $query .= 'WHERE mid IN (';
        $query .= join ', ', map { '?' } @mids;
        $query .= ')';
    }
    $query .= ';';

    my $sth = $self->prepare($query);
    $sth->execute(@mids);

    while (my ($id, $tags, $fields, $model_id) = $sth->fetchrow_array) {
        my $note = Anki::Database::Note->new(
            id     => $id,
            model  => $models->{$model_id},
            fields => $fields,
            tags   => $tags,
        );

        $cb->($note);
    }
}

sub each_card {
    my ($self, $cb, @desired_models) = @_;

    my %is_desired = map { $_ => 1 } @desired_models;
    my $models = $self->models;
    my @mids = map { $_->id } grep { $is_desired{$_->name} } values %$models;

    confess("Mismatch in models: wanted @desired_models, got @mids") if @desired_models != @mids;

    my $query = '
        SELECT cards.id, cards.queue, notes.flds, notes.id, notes.mid, cards.ord, notes.tags
            FROM cards
            JOIN notes ON cards.nid = notes.id
    ';

    if (@mids) {
        $query .= 'WHERE mid IN (';
        $query .= join ', ', map { '?' } @mids;
        $query .= ')';
    }

    my $sth = $self->prepare($query);
    $sth->execute(@mids);

    while (my ($card_id, $queue, $fields, $note_id, $model_id, $ordinal, $tags) = $sth->fetchrow_array) {
        my $card = Anki::Database::Card->new(
            id      => $card_id,
            created => int($card_id / 1000),
            queue   => $queue,
            note_id => $note_id,
            model   => $models->{$model_id},
            fields  => $fields,
            ordinal => $ordinal,
            tags    => $tags,
        );

        $cb->($card);
    }
}

sub first_reviews {
    my ($self) = @_;

    my $sth = $self->prepare('
        SELECT cid, MIN(id)
            FROM revlog
            GROUP BY cid
    ;');
    $sth->execute;

    my %reviews;
    while (my ($card_id, $review) = $sth->fetchrow_array) {
        $reviews{$card_id} = $review / 1000;
    }

    return \%reviews;
}

sub reviews_for_card {
    my ($self, $cid) = @_;
    $cid = $cid->id if blessed $cid;

    my $sth = $self->prepare('
        SELECT id, ease, time, type, ivl
            FROM revlog
            WHERE cid=?
            ORDER BY id ASC
    ;');
    $sth->execute($cid);

    return $sth->fetchall_arrayref;
}

sub reviews_for_deck {
    my ($self, $deck) = @_;
    my $did;

    for my $id (keys %{ $self->decks }) {
      if ($deck eq $id || $self->decks->{$id}->{name} eq $deck) {
        $did = $id;
      }
    }

    if (!$did) {
      confess("No deck '$deck' found");
    }

    my $sth = $self->prepare('
        SELECT
	  revlog.id, revlog.ease, revlog.time, revlog.type, revlog.ivl
        FROM revlog
        LEFT JOIN cards ON revlog.cid = cards.id
	WHERE cards.did = ?
        ORDER BY revlog.id ASC
    ;');
    $sth->execute($did);

    return $sth->fetchall_arrayref;
}

sub day_reviews {
    my ($self, @desired_models) = @_;

    my %is_desired = map { $_ => 1 } @desired_models;
    my $models = $self->models;
    my @mids = map { $_->id } grep { $is_desired{$_->name} } values %$models;

    if (@mids != @desired_models) {
      delete @is_desired{map $_->name, values %$models};
      warn "Mismatch on model names, are these spelled correctly: " . join ', ', sort keys %is_desired;
      return {};
    }

    my $query = '
        SELECT date(revlog.id/1000, "unixepoch") AS day, COUNT(*)
            FROM revlog
    ';

    if (@mids) {
	$query .= '
	  LEFT JOIN cards ON revlog.cid = cards.id
	  LEFT JOIN notes ON cards.nid = notes.id
	  WHERE notes.mid IN (';
        $query .= join ', ', map { '?' } @mids;
        $query .= ')';
    }

    $query .= '
            GROUP BY day
    ';

    my $sth = $self->prepare($query);
    $sth->execute(@mids);

    my %reviews;
    while (my ($day, $count) = $sth->fetchrow_array) {
        $reviews{$day} = $count;
    }

    return \%reviews;
}

sub day_review_time {
    my ($self, @desired_models) = @_;

    my %is_desired = map { $_ => 1 } @desired_models;
    my $models = $self->models;
    my @mids = map { $_->id } grep { $is_desired{$_->name} } values %$models;

    if (@mids != @desired_models) {
      delete @is_desired{map $_->name, values %$models};
      warn "Mismatch on model names, are these spelled correctly: " . join ', ', sort keys %is_desired;
      return {};
    }

    my $query = '
        SELECT date(revlog.id/1000, "unixepoch") AS day, SUM(time)/1000
            FROM revlog
    ';

    if (@mids) {
	$query .= '
	  LEFT JOIN cards ON revlog.cid = cards.id
	  LEFT JOIN notes ON cards.nid = notes.id
	  WHERE notes.mid IN (';
        $query .= join ', ', map { '?' } @mids;
        $query .= ')';
    }

    $query .= '
            GROUP BY day
    ';

    my $sth = $self->prepare($query);
    $sth->execute(@mids);

    my %reviews;
    while (my ($day, $time) = $sth->fetchrow_array) {
        $reviews{$day} = $time;
    }

    return \%reviews;
}

sub card_scores {
    my ($self, $card_id) = @_;

    my $sth = $self->prepare('
        SELECT ease, COUNT(ease)
            FROM revlog
            WHERE cid=?
            GROUP BY ease
    ;');
    $sth->execute($card_id);

    my ($right, $wrong) = (0, 0);
    while (my ($ease, $count) = $sth->fetchrow_array) {
        if ($ease == 1) {
            $wrong += $count;
        }
        else {
            $right += $count;
        }
    }

    return ($right, $wrong);
}

sub field_values {
    my ($self, $field_name, $model_name) = @_;
    my %index_of;
    my @models;

    if ($model_name) {
        my $model = $self->model_named($model_name);
        @models = $model;
        $index_of{ $model->id } = $model->field_index($field_name);
    }
    else {
        @models = $self->models_with_field($field_name);
        for my $model (@models) {
            $index_of{ $model->id } = $model->field_index($field_name);
        }
    }

    my $mids = '(' . (join ', ', map { $_->id } @models) . ')';

    my $sth = $self->prepare("
        SELECT flds, mid
            FROM notes
            WHERE mid in $mids
    ;");
    $sth->execute;

    my @values;
    while (my ($fields, $mid) = $sth->fetchrow_array) {
        my @fields = split "\x1f", $fields;
        push @values, decode_entities($fields[ $index_of{$mid} ]);
    }

    return @values;
}

sub last_new_card {
    my ($self) = @_;

    my $sth = $self->prepare("
        SELECT id
            FROM cards
            ORDER BY cards.id DESC
            LIMIT 1
    ;");
    $sth->execute;
    return ($sth->fetchrow_array)[0];
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;

