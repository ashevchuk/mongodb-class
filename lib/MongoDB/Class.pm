package MongoDB::Class;

our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use MongoDB;
use MongoDB::Class::Connection;
use MongoDB::Class::ConnectionPool::Backup;
use MongoDB::Class::ConnectionPool::Rotated;
use MongoDB::Class::Database;
use MongoDB::Class::Collection;
use MongoDB::Class::Cursor;
use MongoDB::Class::Reference;
use MongoDB::Class::Meta::AttributeTraits;
use Carp;


subtype 'MongoDB::Class::CoercedReference' => as 'MongoDB::Class::Reference';

subtype 'ArrayOfMongoDB::Class::CoercedReference' => as
  'ArrayRef[MongoDB::Class::Reference]';

coerce 'MongoDB::Class::CoercedReference' => from 'Object' => via {
  $_->isa('MongoDB::Class::Reference') ? $_ : MongoDB::Class::Reference->new(
    ref_coll    => $_->_collection->name,
    ref_id      => $_->_id,
    _collection => $_->_collection,
    _class      => 'MongoDB::Class::Reference'
    )
};

coerce 'ArrayOfMongoDB::Class::CoercedReference' => from
  'ArrayRef[Object]'                             => via {
  my @arr;
  foreach my $i (@$_) {
    push(
      @arr,
      $i->isa('MongoDB::Class::Reference')
      ? $i
      : MongoDB::Class::Reference->new(
        ref_coll    => $i->_collection->name,
        ref_id      => $i->_id,
        _collection => $i->_collection,
        _class      => 'MongoDB::Class::Reference'
      )
    );
  }
  return \@arr;
  };

has 'namespace' => (is => 'ro', isa => 'Str', required => 1);

has 'search_dirs' =>
  (is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] });

has 'doc_classes' => (is => 'ro', isa => 'HashRef', default => sub { {} });

sub connect {
  my ($self, %opts) = @_;

  $opts{namespace}   = $self->namespace;
  $opts{doc_classes} = $self->doc_classes;

  return MongoDB::Class::Connection->new(%opts);
}

sub pool {
  my ($self, %opts) = @_;

  $opts{params} ||= {};
  $opts{params}->{namespace}   = $self->namespace;
  $opts{params}->{doc_classes} = $self->doc_classes;

  if ($opts{type} && $opts{type} eq 'rotated') {
    return MongoDB::Class::ConnectionPool::Rotated->new(%opts);
  }
  else {
    return MongoDB::Class::ConnectionPool::Backup->new(%opts);
  }
}

sub BUILD {
  my $self = shift;


  require Module::Pluggable;
  Module::Pluggable->import(
    search_path => [$self->namespace],
    search_dirs => $self->search_dirs,
    require     => 1,
    sub_name    => '_doc_classes'
  );
  foreach ($self->_doc_classes) {
    my $name = $_;
    $name =~ s/$self->{namespace}:://;
    $self->doc_classes->{$name} = $_;
  }
}

__PACKAGE__->meta->make_immutable;
