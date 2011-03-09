# upgrade.pl - Upgrade SQLite database from 3.0.0a3 to 3.0.0a4.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
use 5.010_000;
use strict;
use warnings;
use DBI;
use DBD::SQLite;
use Carp;
use Cwd;
our $Bin = getcwd();

#################
# Configuration #
#################

# Old database filename. (relative to etc/)
my $olddbfile = 'auto.db';
# New database filename. (relative to etc/)
my $newdbfile = 'somebot.db';

##########################
# Program - Don't touch. #
##########################

# Print startup message.
say 'Converting database from Auto-3.0.0a3 format to Auto-3.0.0a4 format...';

# Connect to database.
my $DB = DBI->connect("dbi:SQLite:dbname=$Bin/etc/$olddbfile") or croak 'Failed to open old DB!';

# Query the database for the data from the `qdb` table.
my $dbq = $DB->prepare('SELECT * FROM qdb') or croak 'Failed to query for `qdb` data!';
$dbq->execute() or croak 'Failed to query for `qdb` data!';
my $data = $dbq->fetchall_hashref('key');
my %data = %$data;

# Disconnect from database.
$DB->disconnect;


# Now, connect to the new database so we can enter the data in the new format.
if (!-e "$Bin/etc/$newdbfile") {
    system "touch $Bin/etc/$newdbfile";
    chmod 0755, "$Bin/etc/$newdbfile";
}

$DB = DBI->connect("dbi:SQLite:dbname=$Bin/etc/$newdbfile") or croak 'Failed to open new DB!';

# Create the `qdb` table.
$DB->do('CREATE TABLE IF NOT EXISTS qdb (quoteid INTEGER PRIMARY KEY, creator TEXT, time INT, quote TEXT)') or croak 'Failed to create `qdb` table!';

# Iterate through the data.
foreach my $qid (sort keys %data) {
    # Prepare query to insert data.
    my $ndbq = $DB->prepare('INSERT INTO qdb (quoteid, creator, time, quote) VALUES (?, ?, ?, ?)') or croak 'Failed to query `qdb` table!';

    # Insert data.
    $ndbq->execute($qid, $data{$qid}{creator}, $data{$qid}{'time'}, $data{$qid}{quote}) or croak 'Failed to query `qdb` table!';
}

# Disconnect from database.
$DB->disconnect;

# Success.
say 'Done.';
