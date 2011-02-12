# Module: QDB. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_QDB;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del trans has_priv match_user);
use API::IRC qw(privmsg notice);

sub _init
{
    # Create the QDB command.
    cmd_add('QDB', 0, 0, \%m_QDB::HELP_QDB, \&m_QDB::cmd_qdb) or return;

    # Check for database table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS qdb (key INTEGER PRIMARY KEY, creator TEXT, time INTEGER, quote TEXT)') or return;

    # Success.
    return 1;
}

sub _void
{
    # Delete the QDB command.
    cmd_del('QDB') or return;

    # Success.
    return 1;
}

# Help hash for QDB. Spanish, French and German translations needed.
our %HELP_QDB = (
    'en' => "This command allows you to add, read, and delete quotes. \002Syntax:\002 QDB (ADD|VIEW|COUNT|RAND|DEL) [quote]",
);
sub cmd_qdb
{
    my (%data) = @_;
    my @argv = @{ $data{args} };

    # Check for needed parameter.
    if (!defined $argv[0]) {
        notice($data{svr}, $data{nick}, trans('Not enough parameters').q{.});
        return;
    }
    
    # ADD|VIEW|COUNT|RAND|DEL.
    given (uc $argv[0]) {
        when ('ADD') {
            # QDB ADD.
            if (!defined $argv[1]) {
                notice($data{svr}, $data{nick}, trans('Not enough parameters').q{.});
                return;
            }

            # Get rid of the ADD part.
            shift @argv;

            # Insert into database.
            my $dbq = $Auto::DB->prepare('INSERT INTO qdb (creator, time, quote) VALUES (?, ?, ?)') or 
                notice($data{svr}, $data{nick}, trans('An error occurred').q{.}) and return;
            $dbq->execute($data{nick}, time, join(q{ }, @argv)) or
                notice($data{svr}, $data{nick}, trans('An error occurred').q{.}) and return;

            # Get ID.
            my $count = $Auto::DB->selectrow_array('SELECT COUNT(*) FROM qdb') or
                notice($data{svr}, $data{nick}, trans('An error occurred').q{.}) and return;

            privmsg($data{svr}, $data{chan}, 'Quote successfully submitted. ID: '.$count);
        }
        when ('VIEW') {
            # QDB VIEW.
            if (!defined $argv[1]) {
                notice($data{svr}, $data{nick}, trans('Not enough parameters').q{.});
                return;
            }

            # Get quote.
            my $dbq = $Auto::DB->prepare('SELECT * FROM qdb WHERE key = ?') or
                notice($data{svr}, $data{nick}, trans('An error occurred').'. Quote might not exist.') and return;
            $dbq->execute($argv[1]) or notice($data{svr}, $data{nick}, trans('An error occurred').'. Quote might not exist.') and return;
            my @data = $dbq->fetchrow_array;

            # Send it back.
            privmsg($data{svr}, $data{chan}, "\002Submitted by\002 $data[1] \002on\002 ".POSIX::strftime('%F', localtime($data[2]))." \002at\002 ".POSIX::strftime('%I:%M %p', localtime($data[2])));
            privmsg($data{svr}, $data{chan}, $data[3]);
        }
        when ('COUNT') {
            # Get count.
            my $count = $Auto::DB->selectrow_array('SELECT COUNT(*) FROM qdb') or
                notice($data{svr}, $data{nick}, trans('An error occurred').q{.}) and return;

            # Send it back.
            privmsg($data{svr}, $data{chan}, "There is currently \002$count\002 quotes in my database.");
        }
        when ('RAND') {
            # Get count.
            my $count = $Auto::DB->selectrow_array('SELECT COUNT(*) FROM qdb') or
                notice($data{svr}, $data{nick}, trans('An error occurred').q{.}) and return;

            # Random number.
            my $rand = int(rand($count));
            if ($rand == 0) { $rand = $count; }

            # Get quote.
            my $dbq = $Auto::DB->prepare('SELECT * FROM qdb WHERE key = ?') or
                notice($data{svr}, $data{nick}, trans('An error occurred').q{.}) and return;
            $dbq->execute($rand) or notice($data{svr}, $data{nick}, trans('An error occurred').q{.}) and return;
            my @data = $dbq->fetchrow_array;

            # Send it back.
            privmsg($data{svr}, $data{chan}, "\002ID:\002 $data[0] - \002Submitted by\002 $data[1] \002on\002 ".POSIX::strftime('%F', localtime($data[2]))." \002at\002 ".POSIX::strftime('%I:%M %p', localtime($data[2])));
            privmsg($data{svr}, $data{chan}, $data[3]);
        }
        when ('DEL') {
            # Check for the cmd.qdbdel privilege.
            if (!has_priv(match_user(%data), 'cmd.qdbdel')) {
                notice($data{svr}, $data{chan}, trans('Permission denied').q{.});
                return;
            }
            # Check for the needed parameter.
            if (!defined $argv[1]) {
                notice($data{svr}, $data{nick}, trans('Not enough parameters').q{.});
                return;
            }
            
            # Update database.
            my $dbq = $Auto::DB->do("UPDATE qdb SET quote = \"NOTICE: Quote deleted.\" WHERE key = $argv[1]");

            notice($data{svr}, $data{nick}, (($dbq) ? 'Done.' : trans('An error occurred').q{.}));
        }
        default { notice($data{svr}, $data{nick}, "Unknown action \002".uc($argv[0])."\002. \002Syntax:\002 QDB (ADD|VIEW|COUNT|RAND|DEL) [quote]"); return; }
    }

    return 1;
}


API::Std::mod_init('QDB', 'Xelhua', '1.00', '3.0.0d', __PACKAGE__);
# vim: set ai sw=4 ts=4:
# build: perl=5.010000

__END__

=head1 QDB

=head2 Description

=over

This module adds the QDB (ADD|VIEW|COUNT|RAND|DEL) command, for adding,
viewing, listing number of, viewing a random, deleting a quote from the Auto
database.

=back

=head2 Examples

=over

<JohnSmith> !qdb add <JohnDoe> moocows
<Auto> Quote successfully submitted. ID: 732

=back

=head2 Technical

=over

This module is compatible with Auto v3.0.0a3+.

=back
