# Module: EightBall. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::EightBall;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
our $ANSWER = 0;
my @responses = (
    'Yes!',
    'No!',
    'Yes... No... Yes... No... Hmm... No.',
    'Hmm... it seems likely.',
    'Very unlikely.',
    'Heck no!',
    'Definite yes!',
    'Magic unavailable. Try again later.',
    'Possibly, I wouldn\'t count on it though.',
    'Outcome looks bad.',
    'Outcome looks good.',
    'Can\'t tell now. Maybe another time.',
    'Sorry, but no.',
);

# Initialization subroutine.
sub _init {
    # Create the 8BALL and RIGBALL commands.
    cmd_add('8BALL', 0, 0, \%M::EightBall::HELP_8BALL, \&M::EightBall::c_8ball) or return;
    cmd_add('RIGBALL', 1, 'cmd.rigball', \%M::EightBall::HELP_RIGBALL, \&M::EightBall::rigball) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the 8BALL and RIGBALL commands.
    cmd_del('8BALL') or return;
    cmd_del('RIGBALL') or return;

    # Success.
    return 1;
}

# Help hashes.
our %HELP_8BALL = (
    'en' => "This command will ask the magic 8-Ball your question. \002Syntax:\002 8BALL <question>",
);
our %HELP_RIGBALL = (
    'en' => "This command will \"rig\" (set) the answer of the next 8-Ball question. \002Syntax:\002 RIGBALL <answer>",
);

# Callback for 8BALL command.
sub c_8ball {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Return the question.
    privmsg($src->{svr}, $src->{chan}, "\2Question:\2 ".join q{ }, @argv);

    # Set answer.
    my $answer;
    if (!$ANSWER) {
        $answer = $responses[int rand scalar @responses];
    }
    else {
        $answer = $ANSWER;
        $ANSWER = 0;
    }

    # Return it.
    privmsg($src->{svr}, $src->{chan}, "\2Answer:\2 $answer");

    return 1;
}

# Callback for RIGBALL command.
sub rigball {
    my ($src, @argv) = @_;

    # Check for necessary parameters.
    if (!defined $argv[0]) {
        privmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Return result.
    $ANSWER = join q{ }, @argv;
    privmsg($src->{svr}, $src->{nick}, "Answer set to: $ANSWER");

    return 1;
}


# Start initialization.
API::Std::mod_init('EightBall', 'Xelhua', '2.00', '3.0.0a8', __PACKAGE__);
# build: perl=5.010000

__END__

=head1 NAME

EightBall - A magic eightball module.

=head1 VERSION

 2.00

=head1 SYNOPSIS

 <JohnSmith> !8ball Will I be rich?
 <Auto> Question: Will I be rich?
 <Auto> Answer: Heck no!
 >Auto< rigball Of course!
 <JohnSmith> !8ball Will I be famous?
 <Auto> Question: Will I be famous?
 <Auto> Answer: Of course!

=head1 DESCRIPTION

This module adds the 8BALL and RIGBALL commands, 8BALL is a channel command for
asking the magic 8-Ball a question, RIGBALL is a private command for setting
("rigging") the 8-Ball's next answer.

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
