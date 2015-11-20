package MongoDB::Class::Moose;

our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose ();
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
  with_meta => [
    'belongs_to', 'has_one',      'has_many',  'holds_one',
    'holds_many', 'defines_many', 'joins_one', 'joins_many'
  ],
  also => 'Moose',
);

sub belongs_to {
  my ($meta, $name, %opts) = @_;

  $opts{isa}    = 'MongoDB::Class::CoercedReference';
  $opts{coerce} = 1;

  $meta->add_attribute('_' . $name => %opts);
  $meta->add_method(
    $name => sub {
      my $self = shift;

      my $attr = '_' . $name;
      return unless $self->$attr;
      return $self->$attr->load;
    }
  );
}

sub has_one {
  belongs_to(@_);
}

sub has_many {
  my ($meta, $name, %opts) = @_;

  $opts{isa}    = "ArrayOfMongoDB::Class::CoercedReference";
  $opts{coerce} = 1;

  $meta->add_attribute('_' . $name => %opts);
  $meta->add_method(
    $name => sub {
      my $self = shift;

      my $attr = '_' . $name;

      my @docs;
      foreach (@{$self->$attr || []}) {
        push(@docs, $_->load);
      }
      return @docs;
    }
  );
}

sub holds_one {
  my ($meta, $name, %opts) = @_;

  $opts{documentation} = 'MongoDB::Class::EmbeddedDocument';

  $meta->add_attribute($name => %opts);
}

sub holds_many {
  my ($meta, $name, %opts) = @_;

  $opts{isa}           = "ArrayRef[$opts{isa}]";
  $opts{documentation} = 'MongoDB::Class::EmbeddedDocument';

  $meta->add_attribute('_' . $name => %opts);
  $meta->add_method(
    $name => sub {
      my $self = shift;

      my $attr = '_' . $name;

      return @{$self->$attr || []};
    }
  );
}

sub defines_many {
  my ($meta, $name, %opts) = @_;

  $opts{isa}           = "HashRef[$opts{isa}]";
  $opts{documentation} = 'MongoDB::Class::EmbeddedDocument';

  $meta->add_attribute('_' . $name => %opts);
  $meta->add_method(
    $name => sub {
      my $self = shift;

      my $attr = '_' . $name;

      return $self->$attr || {};
    }
  );
}


sub joins_one {
  my ($meta, $name, %opts) = @_;

  $opts{coll} ||= '<same>';
  $opts{isa} = 'MongoDB::Class::Reference';

  my $ref  = delete $opts{ref};
  my $coll = delete $opts{coll};

  $meta->add_method(
    $name => sub {
      my $self = shift;

      my $coll_name = $coll eq '<same>' ? $self->_collection->name : $coll;

      return $self->_collection->_database->get_collection($coll_name)
        ->find_one({$ref . '.$id' => $self->_id});
    }
  );
}


sub joins_many {
  my ($meta, $name, %opts) = @_;

  $opts{coll} ||= '<same>';
  $opts{isa} = 'MongoDB::Class::Reference';

  my $ref  = delete $opts{ref};
  my $coll = delete $opts{coll};

  $meta->add_method(
    $name => sub {
      my $self = shift;

      my $coll_name = $coll eq '<same>' ? $self->_collection->name : $coll;

      return $self->_collection->_database->get_collection($coll_name)
        ->find({$ref . '.$id' => $self->_id});
    }
  );
}


1;
