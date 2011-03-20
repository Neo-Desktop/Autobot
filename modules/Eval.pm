# Module: Eval. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Eval;
use strict;
use warnings;
use English qw(-no_match_vars);
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);

# Initialization subroutine.
sub _init {
    # Create the EVAL command.
    cmd_add('EVAL', 2, 'cmd.eval', \%M::Eval::HELP_EVAL, \&M::Eval::cmd_eval) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the EVAL command.
    cmd_del('EVAL') or return;

    # Success.
    return 1;
}

# Help hash for EVAL command. Spanish, German and French translations are needed.
our %HELP_EVAL = (
    'en' => "This command allows you to eval Perl code. USE WITH CAUTION. \2Syntax:\2 EVAL <expression>",
);

# Callback for EVAL command.
sub cmd_eval {
    my ($src, @argv) = @_;

    # Check for needed parameter.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Evaluate the expression and return the result.
    my $expr = join ' ', @argv;
    my $result = eval($expr);
    if (!defined $result) { $result = 'None' }
    if ($EVAL_ERROR) {
        $result = $EVAL_ERROR;
        $result =~ s/(\r|\n)//gxsm;
    }

    # Return the result.
    if (!defined $src->{chan}) {
        notice($src->{svr}, $src->{nick}, "Output: $result");
    }
    else {
        privmsg($src->{svr}, $src->{chan}, "$src->{nick}: $result");
    }

    return 1;
}


# Start initialization.
API::Std::mod_init('Eval', 'Xelhua', '1.01', '3.0.0a7', __PACKAGE__);
# build: perl=5.010000

__END__

=head1 NAME

Eval - Allows you to evaluate Perl code from IRC

=head1 VERSION

 1.01

=head1 SYNOPSIS

 >blue< eval 1;
 -blue- Output: 1

=head1 DESCRIPTION

This module adds the EVAL command which allows you to evaluate Perl code from
IRC, returning the output via notice.

This command requires the cmd.eval privilege.

This module is compatible with Auto v3.0.0a7+.

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
