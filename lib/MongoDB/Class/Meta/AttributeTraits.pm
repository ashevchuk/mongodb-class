package MongoDB::Class::Meta::AttributeTraits;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;


package MongoDB::Class::Meta::AttributeTraits::Parsed;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose::Role;
use namespace::autoclean;


has 'parser' => (is => 'ro', isa => 'Str', lazy_build => 1);

sub _build_parser {
  'MongoDB::Class::ParsedAttribute::' . shift->{isa};
}

{

  package Moose::Meta::Attribute::Custom::Trait::Parsed;

  sub register_implementation {
    'MongoDB::Class::Meta::AttributeTraits::Parsed'
  }
}

package MongoDB::Class::Meta::AttributeTraits::Transient;


our $VERSION = "1.000001";
$VERSION = eval $VERSION;

use Moose::Role;
use namespace::autoclean;

{

  package Moose::Meta::Attribute::Custom::Trait::Transient;

  sub register_implementation {
    'MongoDB::Class::Meta::AttributeTraits::Transient'
  }
}


1;
