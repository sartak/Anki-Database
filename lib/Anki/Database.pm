package Anki::Database;
use utf8::all;
use Encode 'decode_utf8';
use Any::Moose;
use DBI;
# ABSTRACT: interact with your Anki (ankisrs.net) database

has file => (
    is       => 'ro',
    isa      => 'Str',
    default  => sub { $ENV{ANKI_DECK} },
);

has dbh => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $dbh = DBI->connect("dbi:SQLite:dbname=" . shift->file);
        $dbh->{sqlite_unicode} = 1;
        $dbh
    },
    handles => ['prepare'],
);

sub readings_for {
    my $self     = shift;
    my $sentence = shift;

    require Text::MeCab;
    my $mecab = Text::MeCab->new;
    my @readings;
    my %seen;

    NODE: for (my $node = $mecab->parse($sentence); $node; $node = $node->next) {
        my @fields = split ',', decode_utf8 $node->feature;
        my $surface = decode_utf8 $node->surface;
        my $dict = $fields[6];
        next unless $dict =~ /\p{Han}/;

        for my $word ($dict, $surface) {
            next if $seen{$word}++;
            my $sth = $self->prepare("
                select fields.value
                from fields
                    join fieldModels on (fields.fieldModelId = fieldModels.id)
                    join models on (fieldModels.modelId = models.id)
                where
                    models.name is '文'
                    and fieldModels.name like '%読み%'
                    and (
                        fields.value like ?
                        or fields.value like ?
                        or fields.value like ?
                    )
                    limit 1;
            ");
            $sth->execute("$word【%", "%\n$word【%", "%<br>$word【%");
            my ($readings) = $sth->fetchrow_array;
            next unless $readings;

            my ($reading) = $readings =~ /(?:<br>|\n|^)\Q$word\E【(.*?)】/;
            push @readings, [$word, $reading];
        }
    }
    return @readings if wantarray;
    return join "\n", map { "$_->[0]【$_->[1]】" } @readings;
}

1;

