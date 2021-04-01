package    # hide from PAUSE
    Params::Validate;

our $VERSION = '1.29';

BEGIN { $ENV{PARAMS_VALIDATE_IMPLEMENTATION} = 'PP' }
use Params::Validate;

1;
