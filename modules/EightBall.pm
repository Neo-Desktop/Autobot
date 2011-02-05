# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_EightBall;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
our $ANSWER = 0;

# Initialization subroutine.
sub _init 
{
    # Create the 8BALL and RIGBALL commands.
	cmd_add("8BALL", 0, 0, \%m_EightBall::HELP_8BALL, \&m_EightBall::c_8ball) or return 0;
	cmd_add("RIGBALL", 1, "cmd.rigball", \%m_EightBall::HELP_RIGBALL, \&m_EightBall::rigball) or return 0;

    # Success.
    return 1;
}

# Void subroutine.
sub _void 
{
    # Delete the 8BALL and RIGBALL commands.
	cmd_del("8BALL") or return 0;
	cmd_del("RIGBALL") or return 0;

    # Success.
	return 1;
}

# Help hashes.
our %HELP_8BALL = (
    'en' => "This command will ask the magic 8-Ball your question. Syntax: 8BALL <question>",
);
our %HELP_RIGBALL = (
    'en' => "This command will \"rig\" (set) the answer of the next 8-Ball question. Syntax: RIGBALL <answer>",
);

# Callback for 8BALL command.
sub c_8ball
{
	my (%data) = @_;
    my @argv = @{ $data{args} }; delete $data{args};

    if (!defined $argv[0]) {
        notice($data{svr}, $data{nick}, trans("Not enough parameters").".");
        return;
    }

    privmsg($data{svr}, $data{chan}, "\002Question:\002 ".join(" ", @argv));
    
    my $a = '';
    if (!$ANSWER) {
        my $rn = int(rand(12));
        given ($rn) {
            when (1) { $a = "Yes!"; }
            when (2) { $a = "No!"; }
            when (3) { $a = "Yes... No... Yes... No... No."; }
            when (4) { $a = "Hmm... it seems likely."; }
            when (5) { $a = "Very unlikely."; }
            when (6) { $a = "Heck no!"; }
            when (7) { $a = "Definite yes!"; }
            when (8) { $a = "Magic unavailable. Try again later."; }
            when (9) { $a = "Possibly, I wouldn't count on it though."; }
            when (10) { $a = "Outcome looks bad."; }
            when (11) { $a = "Outcome looks good."; }
            when (12) { $a = "Can't tell now. Maybe another time."; }
            default { $a = "Sorry, but no."; }
        }
    }
    else {
        $a = $ANSWER;
        $ANSWER = 0;
    }

    privmsg($data{svr}, $data{chan}, "\002Answer:\002 ".$a);
    
	return 1;
}

# Callback for RIGBALL command.
sub rigball 
{
    my (%data) = @_;
    my @argv = @{ $data{args} }; delete $data{args};

    # Check for necessary parameters.
    if (!defined $argv[0]) {
        privmsg($data{svr}, $data{nick}, trans("Not enough parameters").".");
        return;
    }

    $ANSWER = join(" ", @argv);
    privmsg($data{svr}, $data{nick}, "Answer set to: ".$ANSWER);

	return 1;
}


# Start initialization.
API::Std::mod_init("EightBall", "Xelhua", "1.00", "3.0.0d", __PACKAGE__);

__END__

=head1 EightBall

=head2 Description

=over

This module adds the 8BALL and RIGBALL commands, 8BALL is a channel
command for asking the magic 8-Ball a question, RIGBALL is a private
command for setting ("rigging") the 8-Ball's next answer.

=back

=head2 Examples

=over

<JohnSmith> !8ball Will I be rich?
<Auto> Question: Will I be rich?
<Auto> Answer: Heck no!
>Auto< rigball Of course!
<JohnSmith> !8ball Will I be famous?
<Auto> Question: Will I be famous?
<Auto> Answer: Of course!

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hashes.

=back

=head2 Technical

=over

This module is compatible with Auto version 3.0a2+.

=back
