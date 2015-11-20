package MongoDB::Class::Collection;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;
use Carp;
use version;

extends 'MongoDB::Collection';


override 'find' => sub {
  my ($self, $query, $attrs) = @_;


  my ($limit, $skip, $sort_by) = @{$attrs || {}}{qw/limit skip sort_by/};

  $limit ||= 0;
  $skip  ||= 0;

  my $q = {};
  if ($sort_by) {
    $sort_by = Tie::IxHash->new(@$sort_by)
      if ref $sort_by eq 'ARRAY';
    $q->{'query'}   = $query;
    $q->{'orderby'} = $sort_by;
  }
  else {
    $q = $query ? $query : {};
  }

  $q = Tie::IxHash->new(%{$q}) if ref $q eq 'HASH';
  $q = Tie::IxHash->new(@{$q}) if ref $q eq 'ARRAY';

  my $conn_key =
    version->parse($MongoDB::VERSION) < v0.502.0 ? '_connection' : '_client';

  my $cursor = MongoDB::Class::Cursor->new(
    $conn_key => $self->_database->_connection,
    _ns       => $self->full_name,
    _master   => $self->_database->_connection,
    _query    => $q,
    _limit    => $limit,
    _skip     => $skip
  );

  $cursor->_init;

  return $cursor;
};

sub search {
  shift->find(@_);
}


around 'find_one' => sub {
  my ($orig, $self, $orig_query, $fields) = @_;

  my $query = {};

  if ($orig_query && !ref $orig_query && length($orig_query) == 24) {
    $query->{_id} = MongoDB::OID->new(value => $orig_query);
  }
  elsif ($orig_query && ref $orig_query eq 'MongoDB::OID') {
    $query->{_id} = $orig_query;
  }
  elsif ($orig_query) {
    $query = $orig_query;
  }

  return $self->$orig($query, $fields);
};


around 'batch_insert' => sub {
  my ($orig, $self, $docs, $opts) = @_;

  $opts ||= {};
  $opts->{safe} = 1
    if $self->_database->_connection->safe && !defined $opts->{safe};

  foreach (@$docs) {
    next unless ref $_ eq 'HASH' && $_->{_class};
    $_ = $self->_database->_connection->collapse($_);
  }

  if ($opts->{safe}) {
    return map { $self->find_one($_) } $self->$orig($docs, $opts);
  }
  else {
    return $self->$orig($docs, $opts);
  }
};


around 'update' => sub {
  my ($orig, $self, $criteria, $object, $opts) = @_;

  croak 'Criteria for update must be a hash reference (received '
    . ref($criteria) . ').'
    unless ref $criteria eq 'HASH';

  croak 'Object for update must be a hash reference (received '
    . ref($object) . ').'
    unless ref $object eq 'HASH';

  $self->_collapse_hash($object);

  return $self->$orig($criteria, $object, $opts);
};


around 'ensure_index' => sub {
  my ($orig, $self, $keys, $options) = @_;

  if ($keys && ref $keys eq 'ARRAY') {
    $keys = Tie::IxHash->new(@$keys);
  }

  return $self->$orig($keys, $options);
};


sub _collapse_hash {
  my ($self, $object) = @_;

  foreach (keys %$object) {
    if (m/^\$/ && ref $object->{$_} eq 'HASH') {

      $self->_collapse_hash($object->{$_});
    }
    else {
      $object->{$_} =
        $self->_database->_connection->_collapse_val($object->{$_});
    }
  }
}


__PACKAGE__->meta->make_immutable;
