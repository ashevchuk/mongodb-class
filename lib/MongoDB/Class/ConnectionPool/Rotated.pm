package MongoDB::Class::ConnectionPool::Rotated;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;
use Carp;
use Try::Tiny;

with 'MongoDB::Class::ConnectionPool';


sub get_conn {
  my $self = shift;


  if (scalar @{$self->pool} == $self->max_conns
    && $self->num_used < $self->max_conns)
  {
    return $self->_take_from_pool;
  }


  if ($self->num_used < $self->max_conns) {

    return $self->_get_new_conn;
  }


  $self->_set_used(0);
  return $self->_take_from_pool;
}


sub return_conn {return}

sub _take_from_pool {
  my $self = shift;

  my $conn = $self->pool->[$self->num_used];
  $self->_inc_used;
  return $conn;
}

around '_get_new_conn' => sub {
  my ($orig, $self) = @_;

  my $conn = $self->$orig;
  my $pool = $self->pool;
  push(@$pool, $conn);
  $self->_set_pool($pool);
  return $conn;
};


__PACKAGE__->meta->make_immutable;
