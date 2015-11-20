package MongoDB::Class::Connection;

our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;
use Module::Load;
use version;

extends 'MongoDB::MongoClient';

has 'namespace' => (is => 'ro', isa => 'Str', required => 1);

has 'doc_classes' => (is => 'ro', isa => 'HashRef', required => 1);

has 'safe' => (is => 'rw', isa => 'Bool', default => 0);

has 'is_backup' => (is => 'ro', isa => 'Bool', default => 0);

override 'get_database' => sub {
  my $conn_key   = '_client';
  my $bson_codec = MongoDB::BSON->new(
    dbref_callback => sub { return MongoDB::DBRef->new(shift) },
    prefer_numeric => $MongoDB::BSON::looks_like_number || 0,
    ($MongoDB::BSON::char ne '$' ? (op_char => $MongoDB::BSON::char) : ()),
  );

  MongoDB::Class::Database->new(
    $conn_key       => shift,
    name            => shift,
    bson_codec      => $bson_codec,
    max_time_ms     => 1000,
    read_preference => MongoDB::ReadPreference->new,
    write_concern   => MongoDB::WriteConcern->new
  );
};

sub expand {
  my ($self, $coll_ns, $doc) = @_;


  return unless $coll_ns && $doc && ref $doc eq 'HASH';


  my ($db_name, $coll_name) = ($coll_ns =~ m/^([^.]+)\.(.+)$/);


  my $coll = $self->get_database($db_name)->get_collection($coll_name);


  return $doc unless $doc->{_class};


  my $dc_name = $doc->{_class};
  my $ns      = $self->namespace;
  $dc_name =~ s/^${ns}:://;

  my $dc = $self->doc_classes->{$dc_name};

  return $doc unless $dc;


  my %attrs = (
    _collection => $coll,
    _class      => $doc->{_class},
  );

  foreach ($dc->meta->get_all_attributes) {

    if ($_->{isa} eq 'MongoDB::Class::CoercedReference') {
      my $name = $_->name;
      $name =~ s!^_!!;

      next
        unless exists $doc->{$name}
        && defined $doc->{$name}
        && ref $doc->{$name} eq 'HASH'
        && exists $doc->{$name}->{'$ref'}
        && exists $doc->{$name}->{'$id'};

      $attrs{$_->name} = MongoDB::Class::Reference->new(
        _collection => $coll,
        _class      => 'MongoDB::Class::Reference',
        ref_coll    => $doc->{$name}->{'$ref'},
        ref_id      => $doc->{$name}->{'$id'},
      );

    }
    elsif ($_->{isa} eq 'ArrayOfMongoDB::Class::CoercedReference') {
      my $name = $_->name;
      $name =~ s!^_!!;

      next
        unless exists $doc->{$name}
        && defined $doc->{$name}
        && ref $doc->{$name} eq 'ARRAY';

      foreach my $ref (@{$doc->{$name}}) {
        push(
          @{$attrs{$_->name}},
          MongoDB::Class::Reference->new(
            _collection => $coll,
            _class      => 'MongoDB::Class::Reference',
            ref_coll    => $ref->{'$ref'},
            ref_id      => $ref->{'$id'},
          )
        );
      }

    }
    elsif ($_->documentation
      && $_->documentation eq 'MongoDB::Class::EmbeddedDocument')
    {
      my $edc_name = $_->{isa};
      $edc_name =~ s/^${ns}:://;
      if ($_->{isa} =~ m/^ArrayRef/) {
        my $name = $_->name;
        $name =~ s!^_!!;

        $edc_name =~ s/^ArrayRef\[//;
        $edc_name =~ s/\]$//;

        next
          unless exists $doc->{$name}
          && defined $doc->{$name}
          && ref $doc->{$name} eq 'ARRAY';

        $attrs{$_->name} = [];

        foreach my $a (@{$doc->{$name}}) {
          $a->{_class} = $edc_name;
          push(@{$attrs{$_->name}}, $self->expand($coll_ns, $a));
        }
      }
      elsif ($_->{isa} =~ m/^HashRef/) {
        my $name = $_->name;
        $name =~ s!^_!!;

        $edc_name =~ s/^HashRef\[//;
        $edc_name =~ s/\]$//;

        next
          unless exists $doc->{$name}
          && defined $doc->{$name}
          && ref $doc->{$name} eq 'HASH';

        $attrs{$_->name} = {};

        foreach my $key (keys %{$doc->{$name}}) {
          $doc->{$name}->{$key}->{_class} = $edc_name;
          $attrs{$_->name}->{$key} =
            $self->expand($coll_ns, $doc->{$name}->{$key});
        }
      }
      else {
        next unless exists $doc->{$_->name} && defined $doc->{$_->name};
        $doc->{$_->name}->{_class} = $edc_name;
        $attrs{$_->name} = $self->expand($coll_ns, $doc->{$_->name});
      }

    }
    elsif ($_->can('does') && $_->does('Parsed') && $_->parser) {
      next unless exists $doc->{$_->name} && defined $doc->{$_->name};
      load $_->parser;
      my $val = $_->parser->new->expand($doc->{$_->name});
      $attrs{$_->name} = $val if defined $val;

    }
    elsif ($_->can('does') && $_->does('Transient')) {
      next;

    }
    else {
      next unless exists $doc->{$_->name} && defined $doc->{$_->name};
      $attrs{$_->name} = $doc->{$_->name};
    }
  }

  return $dc->new(%attrs);
}

sub collapse {
  my ($self, $doc) = @_;


  return $doc unless $doc->{_class};


  my $dc_name = $doc->{_class};
  my $ns      = $self->namespace;
  $dc_name =~ s/^${ns}:://;

  my $dc = $self->doc_classes->{$dc_name};

  my $new_doc = {_class => $doc->{_class}};

  foreach (keys %$doc) {
    next if $_ eq '_class';

    my $attr = $dc->meta->get_attribute($_);
    if ($attr && $attr->can('does') && $attr->does('Parsed') && $attr->parser)
    {
      load $attr->parser;
      my $parser = $attr->parser->new;
      if (ref $doc->{$_} eq 'ARRAY') {
        my @arr;
        foreach my $val (@{$doc->{$_}}) {
          push(@arr, $parser->collapse($val));
        }
        $new_doc->{$_} = \@arr;
      }
      else {
        $new_doc->{$_} = $parser->collapse($doc->{$_});
      }

    }
    elsif ($attr && $attr->can('does') && $attr->does('Transient')) {
      next;
    }
    else {
      $new_doc->{$_} = $self->_collapse_val($doc->{$_});
    }
  }

  return $new_doc;
}

sub _collapse_val {
  my ($self, $val) = @_;

  if (blessed $val && $val->isa('MongoDB::Class::Reference')) {
    return {'$ref' => $val->ref_coll, '$id' => $val->ref_id};
  }
  elsif (blessed $val
    && $val->can('does')
    && $val->does('MongoDB::Class::Document'))
  {
    return {'$ref' => $val->_collection->name, '$id' => $val->_id};
  }
  elsif (blessed $val
    && $val->can('does')
    && $val->does('MongoDB::Class::EmbeddedDocument'))
  {
    return $val->as_hashref;
  }
  elsif (ref $val eq 'ARRAY') {
    my @arr;
    foreach (@$val) {
      if (blessed $_ && $_->isa('MongoDB::Class::Reference')) {
        push(@arr, {'$ref' => $_->ref_coll, '$id' => $_->ref_id});
      }
      elsif (blessed $_
        && $_->can('does')
        && $_->does('MongoDB::Class::Document'))
      {
        push(@arr, {'$ref' => $_->_collection->name, '$id' => $_->_id});
      }
      elsif (blessed $_
        && $_->can('does')
        && $_->does('MongoDB::Class::EmbeddedDocument'))
      {
        push(@arr, $_->as_hashref);
      }
      else {
        push(@arr, $_);
      }
    }
    return \@arr;
  }
  elsif (ref $val eq 'HASH') {
    my $h = {};
    foreach (keys %$val) {
      if (blessed $val->{$_} && $val->{$_}->isa('MongoDB::Class::Reference'))
      {
        $h->{$_} =
          {'$ref' => $val->{$_}->ref_coll, '$id' => $val->{$_}->ref_id};
      }
      elsif (blessed $val->{$_}
        && $val->{$_}->can('does')
        && $val->{$_}->does('MongoDB::Class::Document'))
      {
        $h->{$_} =
          {'$ref' => $val->{$_}->_collection->name, '$id' => $val->{$_}->_id};
      }
      elsif (blessed $val->{$_}
        && $val->{$_}->can('does')
        && $val->{$_}->does('MongoDB::Class::EmbeddedDocument'))
      {
        $h->{$_} = $val->{$_}->as_hashref;
      }
      else {
        $h->{$_} = $val->{$_};
      }
    }
    return $h;
  }

  return $val;
}

__PACKAGE__->meta->make_immutable;
