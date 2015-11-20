package MongoDB::Class::ParsedAttribute::DateTime;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;
use DateTime::Format::W3CDTF;

with 'MongoDB::Class::ParsedAttribute';


has 'f' => (
  is      => 'ro',
  isa     => 'DateTime::Format::W3CDTF',
  default => sub { DateTime::Format::W3CDTF->new }
);


sub expand {
  return eval { $_[0]->f->parse_datetime($_[1]) } || undef;
}


sub collapse {
  return eval { $_[0]->f->format_datetime($_[1]) } || undef;
}


__PACKAGE__->meta->make_immutable;
