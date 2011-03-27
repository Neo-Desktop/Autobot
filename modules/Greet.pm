# Module: Greet. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Greet;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del hook_add hook_del trans);
use API::IRC qw(privmsg notice);

# Initialization subroutine.
sub _init
{
    # Not compatible with PostgreSQL.
    if ($Auto::ENFEAT =~ /pgsql/) { err(2, 'Unable to load Greet: PostgreSQL is not supported.', 0); return }

    # Create the `greets` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS greets (nick TEXT, greet TEXT)') or return;
    # Create the GREET command.
    cmd_add('GREET', 2, 'cmd.greet', \%M::Greet::HELP_GREET, \&M::Greet::cmd_greet) or return;
    # Create the greet_onjoin hook.
    hook_add('on_rcjoin', 'greet_onjoin', \&M::Greet::hook_rcjoin) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void
{
    # Delete the GREET command.
    cmd_del('GREET') or return;
    # Delete the greet_onjoin hook.
    hook_del('on_rcjoin') or return;

    # Success.
    return 1;
}

# Help hash for GREET. Spanish and French translation needed.
our %HELP_GREET = (
    en => "This command allows management of greets. \2Syntax:\2 GREET (ADD|DEL) [nick] [greet]",
    de => "Dieser Befehl ermoeglicht die Verwaltung von Gruesse. \2Syntax:\2 GREET (ADD|DEL) [nick] [greet]",
);
# Callback for GREET.
sub cmd_greet
{
    my ($src, @argv) = @_;

    # Check for required parameters.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Check what action we're being told to take.
    given (uc $argv[0]) {
        when ('ADD') {
            # GREET ADD
            
            # Check for needed parameters.
            if (!defined $argv[1] or !defined $argv[2]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            my $nick = $argv[1]; shift @argv; shift @argv;
            $nick = lc $nick;
            my $greet = join(' ', @argv);

            # Make sure it doesn't already exist.
            if ($Auto::DB->selectrow_array('SELECT * FROM greets WHERE nick = "'.$nick.'"')) {
                notice($src->{svr}, $src->{nick}, "A greet for \002$nick\002 already exists.");
                return;
            }

            # Insert into database.
            my $dbq = $Auto::DB->prepare('INSERT INTO greets (nick, greet) VALUES (?, ?)') or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            $dbq->execute($nick, $greet) or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;

            API::Log::slog('cmd_greet(): Creating new greet.');
            # Done.
            notice($src->{svr}, $src->{nick}, "Successfully added greet for \002$nick\002.");
        }
        when ('DEL') {
            # GREET DEL
            
            # Check for needed parameters.
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            my $nick = lc $argv[1];

            # Check if there is a greet for this user.
            if (!$Auto::DB->selectrow_array('SELECT * FROM greets WHERE nick = "'.$nick.'"')) {
                notice($src->{svr}, $src->{nick}, "There is no greet for \002$nick\002.");
                return;
            }

            # Delete it.
            $Auto::DB->do('DELETE FROM greets WHERE nick = "'.$nick.'"') or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            notice($src->{svr}, $src->{nick}, "Greet for \002$nick\002 successfully deleted.");
        }
        default { notice($src->{svr}, $src->{nick}, "Unknown action \002$argv[0]\002. \002Syntax:\002 GREET (ADD|DEL)"); return }
    }

    return 1;
}

# Call back for on_rcjoin hook.
sub hook_rcjoin
{
    my (($src, $chan)) = @_;
    my $nick = lc $src->{nick};

    # Check if there's a greet for this user.
    if ($Auto::DB->selectrow_array('SELECT * FROM greets WHERE nick = "'.$nick.'"')) {
        # Get data.
        my @data = $Auto::DB->selectrow_array('SELECT * FROM greets WHERE nick = "'.$nick.'"');
        
        # Send the greet.
        privmsg($src->{svr}, $chan, "[\002".$src->{nick}."\002] ".$data[1]);
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('Greet', 'Xelhua', '1.00', '3.0.0a7', __PACKAGE__);
# build: perl=5.010000

__END__

=head1 Greet

=head2 Description

=over

This module adds GREET ADD|DEL for greet management. Greets are sent when a
user that has a greet in the database joins a channel the bot is in.

=back

=head2 To Do

=over

* Add Spanish and French translations for the help hash.

=back

=head2 Technical

=over

This module is compatible with Auto version 3.0.0a7+.

=back

# vim: set ai et sw=4 ts=4:
