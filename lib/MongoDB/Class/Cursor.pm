package MongoDB::Class::Cursor;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;
use version;

extends 'MongoDB::Cursor';


around 'next' => sub {
  my ($orig, $self, $do_not_expand) = (shift, shift);

  my $doc = $self->$orig || return;

  return $do_not_expand ? $doc : $self->_connection->expand($self->_ns, $doc);
};


around 'sort' => sub {
  my ($orig, $self, $rules) = @_;

  if (ref $rules eq 'ARRAY') {
    return $self->$orig(Tie::IxHash->new(@$rules));
  }
  else {
    return $self->$orig($rules);
  }
};

sub _connection {
  version->parse($MongoDB::VERSION) < v0.502.0
    ? $_[0]->SUPER::_connection
    : $_[0]->_client;
}


__PACKAGE__->meta->make_immutable;
