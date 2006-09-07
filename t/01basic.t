
BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use Test::More tests => 27;

use strict;
use warnings;
use Scalar::Util qw(blessed);

# module loading ok?
BEGIN { use_ok( 'as' ) };

# module to check with
my $Bar;
BEGIN {
    $Bar = 'Bar.pm';
    ok open my $handle, ">$Bar" or die $!;

    print $handle <<'MODULE';
package Bar;
sub new {
    @TESTING::new = @_;
    return bless {}, shift;
}    #new
sub import {
    @TESTING::import = @_;
}    #import
sub unimport {
    @TESTING::unimport = @_;
}    #unimport
1;
MODULE

    ok close $handle;
}    #BEGIN

# basic aliasing
use Bar as => 'Foo';
ok unlink $Bar;

# was import called?
is $TESTING::import[0], 'Bar';
@TESTING::import = ();

# are the stashes ok?
ok %Bar::;
ok %Foo::;
is \%Foo::, \%Bar::;

# original module object creation
my $bar = Bar->new;
is blessed($bar), 'Bar';
is scalar @TESTING::new, 1;
is $TESTING::new[0], 'Bar';
@TESTING::new = ();

# aliased module object creation
my $foo = Foo->new;
is blessed($foo), 'Bar';
is scalar @TESTING::new, 1;
is $TESTING::new[0], 'Foo';
@TESTING::new = ();

# repeated use
eval "use Foo";
ok !$@;
is scalar @TESTING::import, 1;
is $TESTING::import[0], 'Foo';
@TESTING::import = ();

# unuse
eval "no Foo";
ok !$@;
is scalar @TESTING::unimport, 1;
is $TESTING::unimport[0], 'Foo';
@TESTING::unimport = ();

# overloading existing module
eval "use Foo as => 'strict'";
like $@, qr#^Cannot alias 'strict' to 'Foo': already taken#;

# overloading same module
eval "use Bar qw(extra parameters), as =>'Foo'";
ok !$@;
is scalar @TESTING::import, 3;
is $TESTING::import[0], 'Bar';
is $TESTING::import[1], 'extra';
is $TESTING::import[2], 'parameters';
@TESTING::import = ();

# overloading already aliased module
eval "use strict as => 'Foo'";
like $@, qr#^Cannot alias 'Foo' to 'strict': already aliased to 'Bar'#;
