package as;

# make sure we have version info for this module
$VERSION = '0.02';

# be as strict and verbose as possible
use strict;
use warnings;

# modules that we need
use Carp qw(croak);
use Data::Alias qw(alias);

# hash containing already aliased modules
my %ALIASED;

# make sure this is done before anything else
BEGIN {

    # allow dirty stuff happening without anyone complaining about it
    no strict 'refs';
    no warnings 'redefine';

=for Explanation:
     We want to take over the standard -require- functionality so that we
     can inject ourselves in the -use- processing and to install our own
     "import" functionality.  If there is no previous custom installed
     -require- handler yet, then we don't bother calling it, which should
     have some execution benefits.

=cut

    my $old = \&CORE::GLOBAL::require;
    eval { $old->() };
    $old = undef if $@ =~ m#CORE::GLOBAL::require#;

    # install our own -require- handler
    *CORE::GLOBAL::require = sub {

        # perform what was originally expected
        my $return = eval { $old ? $old->( $_[0] ) : CORE::require( $_[0] ) };

        # something wrong, cleanup and bail out
        if ($@) {
            $@ =~ s# in require at as.pm line \d+.\s+##s;
            $@ =~ s# at as.pm line \d+.\s+##s;
            croak $@;
        }

        # not requiring a module, we're done
        my $module = shift;
        return if $module !~ s#\.pm$##;
        $module =~ s#/#::#g;

        # there's an "import" already, embed it
        if ( my $import = $module->can('import') ) {

            # install our own importer
            *{ $module . '::import' } = sub {

                # we need to do aliasing: do it and remove them params
                if ( @_ >= 2 and $_[-2] eq 'as' ) {
                    my ( undef, $alias ) = splice @_, -2;
                    _alias( $module, $alias );
                }

                # hopefully keep same scope as caller
                goto &$import if @_;
            };
        }


        # no import to embed, simply install our own
        else {
            *{ $module . '::import' } = sub {
                return if @_ < 2 or $_[-2] ne 'as';

                # perform the alias
                _alias( $module, $_[-1] );
            };
        }
    };
}     #BEGIN

# satisfy -require-
1;

#---------------------------------------------------------------------------
#
# Internal subroutines
#
#---------------------------------------------------------------------------
# _alias
#
# Perform the actual stash aliasing
#
#  IN: 1 original class name
#      2 alias class name

sub _alias {
    my ( $module, $alias ) = @_;

    # allow dirty stuff happening without anyone complaining about it
    no strict 'refs';

    # make sure we're not treading on already taken territory
    if ( %{ $alias . '::' } ) {

        # alias already used, bail out if not same
        if ( my $old = $ALIASED{$alias} ) {
            croak
              "Cannot alias '$alias' to '$module': already aliased to '$old'"
                if $old ne $module;
        }

        # not aliased yet, but, but, but...
        else {
            croak "Cannot alias '$alias' to '$module': already taken";
        }
    }

    # perform the actual stash aliasing and remember it
    alias %{ $alias . '::' } = %{ $module . '::' };
    $ALIASED{$alias} = $module;

    s#::#/#g foreach ( $module, $alias );
    alias $INC{"$alias.pm"} = $INC{"$module.pm"};
}    #_alias

#---------------------------------------------------------------------------

__END__

=head1 NAME

as - load OO module under another name

=head1 VERSION

This documentation describes version 0.02.

=head1 SYNOPSIS

    use as;  # activate 'use' magic
    
    use Very::Long::Module::Name as => 'Foo';
    use Other::Long::Module::Name qw(parameters being passed), as => 'Bar';

    my $foo = Foo->new; # blessed as Very::Long::Module::Name
    my $bar = Bar->new; # blessed as Other::Long::Module::Name

=head1 DESCRIPTION

Sometimes you get sick of having to use long module names.  This module allows
you to load a module and have it be aliased to another name.

=head1 INSPIRATION

Originaly Inspired by bart's response
(http://www.perlmonks.org/index.pl?node_id=299082) to a thread about long
module names on Perl Monks.  Revived after Data::Alias became available.

=head1 THEORY OF OPERATION

This module injects its own handling of C<require> so that it can intercept
any "as module" parameters.  If found, it will alias the stash of the original
module with the name to be aliased with using L<Data::Alias>.

=head1 CAVEATS

=head2 blessed as what?

Any objects blessed with the aliased class name, will actually return the
original module's name as the classed it has been blessed with.  You could
consider this as either a bug or a feature.

=head2 calling "import" ?

If there is an import class method available for the module being aliased,
then this will only be called if any parameters (others than "as modulename")
have been specified.  This behaviour is based on the fact that this is the
most likely wanted behaviour for object oriented modules, which rarely require
an import method anyway.

=head1 REQUIRED MODULES

 Data::Alias (1.0)

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 COPYRIGHT

Copyright (c) 2003-2006 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
