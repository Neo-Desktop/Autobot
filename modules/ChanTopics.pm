# Module: ChanTopics. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::ChanTopics;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(notice topic);

# Initialization subroutine.
sub _init
{
    # PostgreSQL is not supported.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load ChanTopics: PostgreSQL is not supported.', 0); return }
    
    # Create database table if it's missing.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS topics (net TEXT, chan TEXT, topic TEXT, divider TEXT, owner TEXT, verb TEXT, status TEXT, other TEXT, static TEXT)') or print "$!\n" and return;

    # Create the TOPIC command.
    cmd_add('TOPIC', 0, 'topic.topic', \%M::ChanTopics::HELP_TOPIC, \&M::ChanTopics::cmd_topic) or return;
    # Create the DIVIDER command.
    cmd_add('DIVIDER', 0, 'topic.topic', \%M::ChanTopics::HELP_DIVIDER, \&M::ChanTopics::cmd_divider) or return;
    # Create the OWNER command.
    cmd_add('OWNER', 0, 'topic.owner', \%M::ChanTopics::HELP_OWNER, \&M::ChanTopics::cmd_owner) or return;
    # Create the VERB command.
    cmd_add('VERB', 0, 'topic.status', \%M::ChanTopics::HELP_VERB, \&M::ChanTopics::cmd_verb) or return;
    # Create the STATUS command.
    cmd_add('STATUS', 0, 'topic.status', \%M::ChanTopics::HELP_STATUS, \&M::ChanTopics::cmd_status) or return;
    # Create the OTHER command.
    cmd_add('OTHER', 0, 'topic.static', \%M::ChanTopics::HELP_OTHER, \&M::ChanTopics::cmd_other) or return;
    # Create the STATIC command.
    cmd_add('STATIC', 0, 'topic.static', \%M::ChanTopics::HELP_STATIC, \&M::ChanTopics::cmd_static) or return;
    # Create the TSYNC command.
    cmd_add('TSYNC', 0, 'topic.topic', \%M::ChanTopics::HELP_TSYNC, \&M::ChanTopics::cmd_tsync) or return;

    return 1;
}

# Void subroutine.
sub _void
{
    # Delete all the commands.
    cmd_del('TOPIC') or return;
    cmd_del('DIVIDER') or return;
    cmd_del('OWNER') or return;
    cmd_del('VERB') or return;
    cmd_del('STATUS') or return;
    cmd_del('OTHER') or return;
    cmd_del('STATIC') or return;
    cmd_del('TSYNC') or return;

    return 1;
}

# Help hashes for the TOPIC, OWNER, VERB, STATUS, OTHER, STATIC, DIVIDER and TSYNC commands. Spanish, French and German translations needed.
our %HELP_TOPIC = (
    'en' => "This command allows you to set the topic section of a channel topic. \002Syntax:\002 TOPIC <new topic>",
);
our %HELP_DIVIDER = (
    'en' => "This command allows you to set the divider for topic sections in a channel topic. \002Syntax:\002 DIVIDER <new divider>",
);
our %HELP_OWNER = (
    'en' => "This command allows you to set the channel owner section of a channel topic. \002Syntax:\002 OWNER <new owner>",
);
our %HELP_VERB = (
    'en' => "This command allows you to set the status verb section of a channel topic. \002Syntax:\002 VERB <new verb>",
);
our %HELP_STATUS = (
    'en' => "This command allows you to set the status section of a channel topic. \002Syntax:\002 STATUS <new status>",
);
our %HELP_OTHER = (
    'en' => "This command allows you to set the other static section of a channel topic. \002Syntax:\002 OTHER <new other static>",
);
our %HELP_STATIC = (
    'en' => "This command allows you to set the static section of a channel topic. \002Syntax:\002 STATIC <new static>",
);
our %HELP_TSYNC = (
    'en' => "This command allows you to sync the channel topic with the topic in the database. \002Syntax:\002 TSYNC",
);

# Callback for TOPIC command.
sub cmd_topic
{
    my ($src, @argv) = @_;

    # Check for required parameters.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Get existing topic data.
    my (undef, $div, $owner, $verb, $status, $other, $static) = _getdata(lc $src->{svr}, lc $src->{chan});

    # Query the database with the new topic.
    my $dbq = $Auto::DB->prepare('UPDATE topics SET topic = ? WHERE net = ? AND chan = ?') or return;
    $dbq->execute(join(' ', @argv), lc $src->{svr}, lc $src->{chan}) or return;

    # Set new topic.
    topic($src->{svr}, $src->{chan}, "Topic: ".join(' ', @argv)." $div $owner $verb $status $div $other $div $static");

    return 1;
}

# Callback for DIVIDER command.
sub cmd_divider
{
    my ($src, @argv) = @_;

    # Check for required parameters.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Get existing topic data.
    my ($topic, undef, $owner, $verb, $status, $other, $static) = _getdata(lc $src->{svr}, lc $src->{chan});

    # Query the database with the new divider.
    my $dbq = $Auto::DB->prepare('UPDATE topics SET divider = ? WHERE net = ? AND chan = ?') or return;
    $dbq->execute($argv[0], lc $src->{svr}, lc $src->{chan}) or return;

    # Set new topic.
    topic($src->{svr}, $src->{chan}, "Topic: $topic $argv[0] $owner $verb $status $argv[0] $other $argv[0] $static");

    return 1;
}

# Callback for OWNER command.
sub cmd_owner
{
    my ($src, @argv) = @_;

    # Check for required parameters.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Get existing topic data.
    my ($topic, $div, undef, $verb, $status, $other, $static) = _getdata(lc $src->{svr}, lc $src->{chan});

    # Query the database with the new owner.
    my $dbq = $Auto::DB->prepare('UPDATE topics SET owner = ? WHERE net = ? AND chan = ?') or return;
    $dbq->execute($argv[0], lc $src->{svr}, lc $src->{chan}) or return;

    # Set new topic.
    topic($src->{svr}, $src->{chan}, "Topic: $topic $div $argv[0] $verb $status $div $other $div $static");

    return 1;
}

# Callback for VERB command.
sub cmd_verb
{
    my ($src, @argv) = @_;

    # Check for required parameters.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Get existing topic data.
    my ($topic, $div, $owner, undef, $status, $other, $static) = _getdata(lc $src->{svr}, lc $src->{chan});

    # Query the database with the new verb.
    my $dbq = $Auto::DB->prepare('UPDATE topics SET verb = ? WHERE net = ? AND chan = ?') or return;
    $dbq->execute($argv[0], lc $src->{svr}, lc $src->{chan}) or return;

    # Set new topic.
    topic($src->{svr}, $src->{chan}, "Topic: $topic $div $owner $argv[0] $status $div $other $div $static");

    return 1;
}

# Callback for STATUS command.
sub cmd_status
{
    my ($src, @argv) = @_;

    # Check for required parameters.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Get existing topic data.
    my ($topic, $div, $owner, $verb, undef, $other, $static) = _getdata(lc $src->{svr}, lc $src->{chan});

    # Query the database with the new status.
    my $dbq = $Auto::DB->prepare('UPDATE topics SET status = ? WHERE net = ? AND chan = ?') or return;
    $dbq->execute(join(' ', @argv), lc $src->{svr}, lc $src->{chan}) or return;

    # Set new topic.
    topic($src->{svr}, $src->{chan}, "Topic: $topic $div $owner $verb ".join(' ', @argv)." $div $other $div $static");

    return 1;
}

# Callback for OTHER command.
sub cmd_other
{
    my ($src, @argv) = @_;

    # Check for required parameters.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Get existing topic data.
    my ($topic, $div, $owner, $verb, $status, undef, $static) = _getdata(lc $src->{svr}, lc $src->{chan});

    # Query the database with the new other.
    my $dbq = $Auto::DB->prepare('UPDATE topics SET other = ? WHERE net = ? AND chan = ?') or return;
    $dbq->execute(join(' ', @argv), lc $src->{svr}, lc $src->{chan}) or return;

    # Set new topic.
    topic($src->{svr}, $src->{chan}, "Topic: $topic $div $owner $verb $status $div ".join(' ', @argv)." $div $static");

    return 1;
}

# Callback for STATIC command.
sub cmd_static
{
    my ($src, @argv) = @_;

    # Check for required parameters.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Get existing topic data.
    my ($topic, $div, $owner, $verb, $status, $other, undef) = _getdata(lc $src->{svr}, lc $src->{chan});

    # Query the database with the new static.
    my $dbq = $Auto::DB->prepare('UPDATE topics SET static = ? WHERE net = ? AND chan = ?') or return;
    $dbq->execute(join(' ', @argv), lc $src->{svr}, lc $src->{chan}) or return;

    # Set new topic.
    topic($src->{svr}, $src->{chan}, "Topic: $topic $div $owner $verb $status $div $other $div ".join(' ', @argv));

    return 1;
}

# Callback for TSYNC command.
sub cmd_tsync
{
    my ($src, @argv) = @_;

    # Get the topic data.
    my ($topic, $div, $owner, $verb, $status, $other, $static) = _getdata(lc $src->{svr}, lc $src->{chan});

    # Set new topic.
    topic($src->{svr}, $src->{chan}, "Topic: $topic $div $owner $verb $status $div $other $div $static");

    return 1;
}

# Subroutine for getting topic data.
sub _getdata
{
    my ($net, $chan) = @_;

    # Check if there is a database entry for this channel.
    if (!$Auto::DB->selectrow_array('SELECT * FROM topics WHERE net = "'.$net.'" AND chan = "'.$chan.'"')) {
        # There is not; create it.
        my $dbq = $Auto::DB->prepare('INSERT INTO topics (net, chan, topic, divider, owner, verb, status, other, static) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)') or return;
        $dbq->execute($net, $chan, 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL') or return;
    }

    # Now retrieve all the desired data.
    my $dbq = $Auto::DB->prepare('SELECT topic,divider,owner,verb,status,other,static FROM topics WHERE net = ? AND chan = ?') or return;
    $dbq->execute($net, $chan) or return;
    my $data = $dbq->fetchrow_hashref or return;
    
    # And return it.
    return ($data->{topic}, $data->{divider}, $data->{owner}, $data->{verb}, $data->{status}, $data->{other}, $data->{static});
}


API::Std::mod_init('ChanTopics', 'Xelhua', '1.00', '3.0.0a7', __PACKAGE__);
# build: perl=5.010000

__END__

=head1 ChanTopics

=head2 Description

=over

This module adds the TOPIC, DIVIDER, OWNER, VERB, STATUS, OTHER and STATIC
commands for advanced yet simple management of a channel's topic.

Topic Format: Topic: TOPIC DIVIDER OWNER VERB STATUS DIVIDER OTHER DIVIDER STATIC

=back

=head2 How To Use

=over

This module adds the topic.topic, topic.owner, topic.status and topic.static
privileges. topic.topic grants access to TOPIC, topic.owner to OWNER,
topic.status to VERB and STATUS, and topic.static to OTHER and STATIC.

=back

=head2 Examples

=over

<JohnSmith> !topic Random Nonsense
* Auto changes topic to: Topic: Random Nonsense | JohnSmith is here | Welcome to #johnsmith | Website at http://example.com
<JohnSmith> !status sleeping
* Auto changes topic to: Topic: Random Nonsense | JohnSmith is sleeping | Welcome to #johnsmith | Website at http://example.com

=back

=head2 To Do

=over

* Spanish, French and German translations for the help hashes.

=back

=head2 Technical

=over

This module adds no extra dependencies.

This module is not compatible with PostgreSQL, yet.

This module is compatible with Auto v3.0.0a7+.

Ported from v1.0.

=back

# vim: set ai et sw=4 ts=4:
