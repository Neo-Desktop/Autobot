# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_Badwords;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(hook_add hook_del conf_get err);
use API::IRC qw(privmsg notice kick cmode);

# Initialization subroutine.
sub _init 
{
    # Check for required configuration values.
	if (!conf_get('badwords')) {
		err(2, 'Please verify that you have a badwords block with word entries defined in your configuration file.', 0);
		return;
	}
    # Create the act_on_badword hook.
	hook_add('on_cprivmsg', 'act_on_badword', \&m_Badwords::actonbadword) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void 
{
    # Delete the act_on_badword hook.
	hook_del('act_on_badword') or return 0;

    # Success.
	return 1;
}

# Callback for act_on_badword hook.
sub actonbadword
{
	my (($svr, @ex)) = @_;
    my %src = API::IRC::usrc(substr $ex[0], 1);

	my $msg = substr $ex[3], 1;
    for (my $i = 4; $i < scalar @ex; $i++) { $msg .= q{ }.$ex[$i]; }

    if (conf_get("badwords:$ex[2]:word")) {
        my @words = @{ (conf_get("badwords:$ex[2]:word"))[0] };

        foreach (@words) {
            my ($w, $a) = split m/[:]/, $_;

            if ($msg =~ m/($w)/ixsm) {
                given ($a) {
                    when ('kick') { 
                        kick($svr, $ex[2], $src{nick}, 'Foul language is prohibited here.'); 
                    }
                    when ('kickban') { 
                        cmode($svr, $ex[2], '+b *!*@'.$src{host}); 
                        kick($svr, $ex[2], $src{nick}, 'Foul language is prohibited here.'); 
                    }
                    when ('quiet') { 
                        cmode($svr, $ex[2], '+q *!*@'.$src{host}); 
                    }
                    default { 
                        kick($svr, $ex[2], $src{nick}, 'Foul language is prohibited here.'); 
                    }
                }
            }
        }
    }

    return 1;
}


API::Std::mod_init("Badwords", "Xelhua", "1.00", "3.0.0d", __PACKAGE__);

__END__

=head1 Badwords

=head2 Description

=over

This module adds the ability to kick/ban a user if a configured word is
sent by them in a PRIVMSG to a configured channel using a badwords block.

=back

=head2 How To Use

=over

Add Badwords to module auto-load and the following to your configuration file:

  badwords "#channel" {
    word "foo:kick";
    word "bar:kickban";
    word "moo:quiet";
    word "cows:kickban";
  }

Changing the obvious to your wish.

=back

=head2 Examples

=over

  badwords "#johnsmith" {
    word "moo:ban";
  }

<troll> moo
* Auto sets mode +b *!*@troll.com
* Auto has kicked troll from #johnsmith (Foul language is prohibited here.)

=back

=head2 Technical

=over

This module is compatible with Auto version 3.0.0a3+.

=back
