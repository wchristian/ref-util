package Hello::World;

use strict;
use warnings;
use XSLoader;

use Exporter 5.57 'import';

our $VERSION     = '0.021';
our %EXPORT_TAGS = ( 'all' => [ qw< mix distance > ] );
our @EXPORT      = ();
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );

XSLoader::load( 'Hello::World', $VERSION );

1;
