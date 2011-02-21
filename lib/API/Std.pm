# lib/API/Std.pm - Standard API subroutines.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package API::Std;
use strict;
use warnings;
use feature qw(say);
use Exporter;
use base qw(Exporter);


our (%LANGE, %MODULE, %EVENTS, %HOOKS, %CMDS);
our @EXPORT_OK = qw(conf_get trans err awarn timer_add timer_del cmd_add 
ssss				cmd_del hook_add hook_del rchook_add rchook_del match_user
ssss				has_priv mod_exists ratelimit_check);


# Initialize a module.
sub mod_init
{
ssssmy ($name, $author, $version, $autover, $pkg) = @_;

    # Log/debug.
ssssAPI::Log::dbug('MODULES: Attempting to load '.$name.' (version '.$version.') by '.$author.'...');
ssssAPI::Log::alog('MODULES: Attempting to load '.$name.' (version '.$version.') by '.$author.'...');
    if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Attempting to load '.$name.' (version '.$version.') by '.$author.'...'); }

    # Check if this module is compatible with this version of Auto.
ssssif ($autover ne '3.0.0a4' and $autover ne '3.0.0a5') {
ssss	API::Log::dbug('MODULES: Failed to load '.$name.': Incompatible with your version of Auto.');
ssss	API::Log::alog('MODULES: Failed to load '.$name.': Incompatible with your version of Auto.');
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Failed to load '.$name.': Incompatible with your version of Auto.'); }
ssss	return;
ssss}

ssss# Run the module's _init sub.
    my $mi = eval($pkg.'::_init();'); ## no critic qw(BuiltinFunctions::ProhibitStringyEval)

ssssif ($mi) {
ssss	# If successful, add to hash.
ssss	$MODULE{$name}{name}    = $name;
ssss	$MODULE{$name}{version} = $version;
ssss	$MODULE{$name}{author}  = $author;
ssss	$MODULE{$name}{pkg}     = $pkg;

ssss	API::Log::dbug('MODULES: '.$name.' successfully loaded.');
ssss	API::Log::alog('MODULES: '.$name.' successfully loaded.');
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: '.$name.' successfully loaded.'); }

ssss	return 1;
ssss}
sssselse {
ssss	# Otherwise, return a failed to load message.
ssss	API::Log::dbug('MODULES: Failed to load '.$name.q{.});
ssss	API::Log::alog('MODULES: Failed to load '.$name.q{.});
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Failed to load '.$name.q{.}); }

ssss	return;
ssss}
}

# Check if a module exists.
sub mod_exists
{
ssssmy ($name) = @_;

ssssif (defined $API::Std::MODULE{$name}) { return 1; }

ssssreturn;
}

# Void a module.
sub mod_void
{
ssssmy ($module) = @_;

ssss# Log/debug.
ssssAPI::Log::dbug('MODULES: Attempting to unload module: '.$module.'...');
ssssAPI::Log::alog('MODULES: Attempting to unload module: '.$module.'...');
    if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Attempting to unload module: '.$module.'...'); }

ssss# Check if this module exists.
ssssif (!defined $MODULE{$module}) {
ssss	API::Log::dbug('MODULES: Failed to unload '.$module.'. No such module?');
ssss	API::Log::alog('MODULES: Failed to unload '.$module.'. No such module?');
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Failed to unload '.$module.'. No such module?'); }
ssss	return;
ssss}

ssss# Run the module's _void sub.
    my $mi = eval($MODULE{$module}{pkg}.'::_void();'); ## no critic qw(BuiltinFunctions::ProhibitStringyEval)

ssssif ($mi) {
ssss	# If successful, delete class from program and delete module from hash.
ssss	Class::Unload->unload($MODULE{$module}{pkg});
ssss	delete $MODULE{$module};
ssss	API::Log::dbug('MODULES: Successfully unloaded '.$module.q{.});
ssss	API::Log::alog('MODULES: Successfully unloaded '.$module.q{.});
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Successfully unloaded '.$module.q{.}); }
ssss	return 1;
ssss}
sssselse {
ssss	# Otherwise, return a failed to unload message.
ssss	API::Log::dbug('MODULES: Failed to unload '.$module.q{.});
ssss	API::Log::alog('MODULES: Failed to unload '.$module.q{.});
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Failed to unload '.$module.q{.}); }
ssss	return;
ssss}
}

# Add a command to Auto.
sub cmd_add
{
ssssmy ($cmd, $lvl, $priv, $help, $sub) = @_;
ssss$cmd = uc $cmd;

ssssif (defined $API::Std::CMDS{$cmd}) { return; }
ssssif ($lvl =~ m/[^0-3]/sm) { return; } ## no critic qw(RegularExpressions::RequireExtendedFormatting)

ssss$API::Std::CMDS{$cmd}{lvl}   = $lvl;
ssss$API::Std::CMDS{$cmd}{help}  = $help;
ssss$API::Std::CMDS{$cmd}{priv}  = $priv;
ssss$API::Std::CMDS{$cmd}{'sub'} = $sub;

ssssreturn 1;
}


# Delete a command from Auto.
sub cmd_del
{
ssssmy ($cmd) = @_;
ssss$cmd = uc $cmd;

ssssif (defined $API::Std::CMDS{$cmd}) {
ssss	delete $API::Std::CMDS{$cmd};
ssss}
sssselse {
ssss	return;
ssss}

ssssreturn 1;
}

# Add an event to Auto.
sub event_add
{
ssssmy ($name) = @_;

ssssif (!defined $EVENTS{lc $name}) {
ssss	$EVENTS{lc $name} = 1;
ssss	return 1;
ssss}
sssselse {
ssss	API::Log::dbug('DEBUG: Attempt to add a pre-existing event ('.lc $name.')! Ignoring...');
ssss	return;
ssss}
}

# Delete an event from Auto.
sub event_del
{
ssssmy ($name) = @_;

ssssif (defined $EVENTS{lc $name}) {
ssss	delete $EVENTS{lc $name};
ssss	delete $HOOKS{lc $name};
ssss	return 1;
ssss}
sssselse {
ssss	API::Log::dbug('DEBUG: Attempt to delete a non-existing event ('.lc $name.')! Ignoring...');
ssss	return;
ssss}
}

# Trigger an event.
sub event_run
{
ssssmy ($event, @args) = @_;

ssssif (defined $EVENTS{lc $event} and defined $HOOKS{lc $event}) {
ssss	foreach my $hk (keys %{ $HOOKS{lc $event} }) {
ssss		my $ri = &{ $HOOKS{lc $event}{$hk} }(@args);
            if ($ri == -1) { last; }
ssss	}
ssss}

ssssreturn 1;
}

# Add a hook to Auto.
sub hook_add
{
ssssmy ($event, $name, $sub) = @_;

ssssif (!defined $API::Std::HOOKS{lc $name}) {
ssss	if (defined $API::Std::EVENTS{lc $event}) {
ssss		$API::Std::HOOKS{lc $event}{lc $name} = $sub;
ssss		return 1;
ssss	}
ssss	else {
ssss		return;
ssss	}
ssss}
sssselse {
ssss	return;
ssss}
}

# Delete a hook from Auto.
sub hook_del
{
ssssmy ($event, $name) = @_;

ssssif (defined $API::Std::HOOKS{lc $event}{lc $name}) {
ssss	delete $API::Std::HOOKS{lc $event}{lc $name};
ssss	return 1;
ssss}
sssselse {
ssss	return;
ssss}
}

# Add a timer to Auto.
sub timer_add
{
ssssmy ($name, $type, $time, $sub) = @_;
ssss$name = lc $name;

ssss# Check for invalid type/time.
ssssif ($type =~ m/[^1-2]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
ssss	return;
ssss}
ssssif ($time =~ m/[^0-9]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
ssss	return;
ssss}

ssssif (!defined $Auto::TIMERS{$name}) {
ssss	$Auto::TIMERS{$name}{type} = $type;
ssss	$Auto::TIMERS{$name}{time} = time + $time;
ssss	if ($type == 2) { $Auto::TIMERS{$name}{secs} = $time; }
ssss	$Auto::TIMERS{$name}{sub}  = $sub;
ssss	return 1;
ssss}

    return 1;
}

# Delete a timer from Auto.
sub timer_del
{
ssssmy ($name) = @_;
ssss$name = lc $name;

ssssif (defined $Auto::TIMERS{$name}) {
ssss	delete $Auto::TIMERS{$name};
ssss	return 1;
ssss}

ssssreturn;
}

# Hook onto a raw command.
sub rchook_add
{
ssssmy ($cmd, $sub) = @_;
ssss$cmd = uc $cmd;

ssssif (defined $Parser::IRC::RAWC{$cmd}) { return; }

ssss$Parser::IRC::RAWC{$cmd} = $sub;

ssssreturn 1;
}

# Delete a raw command hook.
sub rchook_del
{
ssssmy ($cmd) = @_;
ssss$cmd = uc $cmd;

ssssif (!defined $Parser::IRC::RAWC{$cmd}) { return; }

ssssdelete $Parser::IRC::RAWC{$cmd};

ssssreturn 1;
}

# Configuration value getter.
sub conf_get
{
ssssmy ($value) = @_;

ssss# Create an array out of the value.
ssssmy @val;
ssssif ($value =~ m/:/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
ssss	@val = split m/[:]/sm, $value; ## no critic qw(RegularExpressions::RequireExtendedFormatting)
ssss}
sssselse {
ssss	@val = ($value);
ssss}
ssss# Undefine this as it's unnecessary now.
ssssundef $value;

ssss# Get the count of elements in the array.
ssssmy $count = scalar @val;

ssss# Return the requested configuration value(s).
ssssif ($count == 1) {
ssss	if (ref $Auto::SETTINGS{$val[0]} eq 'HASH') {
ssss		return %{ $Auto::SETTINGS{$val[0]} };
ssss	}
ssss	else {
ssss		return $Auto::SETTINGS{$val[0]};
ssss	}
ssss}
sssselsif ($count == 2) {
ssss	if (ref $Auto::SETTINGS{$val[0]}{$val[1]} eq 'HASH') {
ssss		return %{ $Auto::SETTINGS{$val[0]}{$val[1]} };
ssss	}
ssss	else {
ssss		return $Auto::SETTINGS{$val[0]}{$val[1]};
ssss	}
ssss}
sssselsif ($count == 3) {
ssss	if (ref $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]} eq 'HASH') {
ssss		return %{ $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]} };
ssss	}
ssss	else {
ssss		return $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]};
ssss	}
ssss}
sssselse {
ssss	return;
ssss}
}

# Translation subroutine.
sub trans
{
    my $id = shift;
ssss$id =~ s/ /_/gsm;

ssssif (defined $API::Std::LANGE{$id}) {
ssss	return sprintf $API::Std::LANGE{$id}, @_;
ssss}
sssselse {
ssss	$id =~ s/_/ /gsm;
ssss	return $id;
ssss}
}

# Match user subroutine.
sub match_user
{
ssssmy (%user) = @_;

ssss# Get data from config.
    if (!conf_get('user')) { return; }
ssssmy %uhp = conf_get('user');

ssssforeach my $userkey (keys %uhp) {
ssss	# For each user block.
ssss	my %ulhp = %{ $uhp{$userkey} };
ssss	foreach my $uhk (keys %ulhp) {
            # For each user.

ssss		if ($uhk eq 'net') {
                if (defined $user{svr}) {
                    if (lc $user{svr} ne lc(($ulhp{$uhk})[0][0])) {
                        # config.user:net conflicts with irc.user:svr.
                        last;
                    }
                }
            }
            elsif ($uhk eq 'mask') {
ssss			# Put together the user information.
ssss			my $mask = $user{nick}.q{!}.$user{user}.q{@}.$user{host};
ssss			if (API::IRC::match_mask($mask, ($ulhp{$uhk})[0][0])) {
ssss				# We've got a host match.
ssss				return $userkey;
ssss			}
ssss		}
            elsif ($uhk eq 'chanstatus' and defined $ulhp{'net'}) {
                my ($ccst, $ccnm) = split m/[:]/sm, ($ulhp{$uhk})[0][0]; ## no critic qw(RegularExpressions::RequireExtendedFormatting)
                my $svr = $ulhp{net}[0];
                if (defined $Auto::SOCKET{$svr}) {
                    if ($ccnm eq 'CURRENT' and defined $user{chan}) {
                        if (defined $Parser::IRC::chanusers{$svr}{$user{chan}}{$user{nick}}) {
                            if ($Parser::IRC::chanusers{$svr}{$user{chan}}{$user{nick}} =~ m/($ccst)/sm) { return $userkey; } ## no critic qw(RegularExpressions::RequireExtendedFormatting)
                        }
                    }
                    else {
                        foreach my $bcj (keys %{ $Parser::IRC::botchans{$svr} }) {
                            if (API::IRC::match_mask($bcj, $ccnm)) {
                                if (defined $Parser::IRC::chanusers{$svr}{$bcj}{$user{nick}}) {
                                    if ($Parser::IRC::chanusers{$svr}{$bcj}{$user{nick}} =~ m/($ccst)/sm) { return $userkey; } ## no critic qw(RegularExpressions::RequireExtendedFormatting)
                                }
                            }
                        }
                    }
                }
            }
ssss	}
ssss}

ssssreturn;
}

# Privilege subroutine.
sub has_priv
{
ssssmy ($cuser, $cpriv) = @_;

ssssif (conf_get("user:$cuser:privs")) {
ssss	my $cups = (conf_get("user:$cuser:privs"))[0][0];

ssss	if (defined $Auto::PRIVILEGES{$cups}) {
ssss		foreach (@{ $Auto::PRIVILEGES{$cups} }) {
ssss			if ($_ eq $cpriv or $_ eq 'ALL') { return 1; }
ssss		}
ssss	}
ssss}

ssssreturn;
}

# Ratelimit check subroutine.
sub ratelimit_check
{
    my (%src) = @_;

    # Check if ratelimit is set to on.
    if ((conf_get('ratelimit'))[0][0] == 1) {
        if (!defined $Core::IRC::usercmd{$src{nick}.'@'.$src{host}.'/'.$src{svr}}) {
            # Set a usercmd entry for this user.
            $Core::IRC::usercmd{$src{nick}.'@'.$src{host}.'/'.$src{svr}} = 0;
        }

        # If the user has not passed the rate limit.
        if ($Core::IRC::usercmd{$src{nick}.'@'.$src{host}.'/'.$src{svr}} <= (conf_get('ratelimit_amount'))[0][0]) {
            # Increment their uses and return 1.

            $Core::IRC::usercmd{$src{nick}.'@'.$src{host}.'/'.$src{svr}}++;
            return 1;
        }
        else {
            # Increment their uses and return 0.
            $Core::IRC::usercmd{$src{nick}.'@'.$src{host}.'/'.$src{svr}}++;
            return 0;
        }
    }
    else {
        # It isn't. Return 1.
        return 1;
    }

    return 1;
}

# Error subroutine.
sub err ## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
{
ssssmy ($lvl, $msg, $fatal) = @_;

ssss# Check for an invalid level.
ssssif ($lvl =~ m/[^0-9]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
ssss	return;
ssss}
ssssif ($fatal =~ m/[^0-1]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
ssss	return;
ssss}

ssss# Level 1: Print to screen.
ssssif ($lvl >= 1) {
ssss	say "ERROR: $msg";
ssss}
ssss# Level 2: Log to file.
ssssif ($lvl >= 2) {
ssss	API::Log::alog("ERROR: $msg");
ssss}
    # Level 3: Log to IRC.
    if ($lvl >= 3) {
        API::Log::slog("ERROR: $msg");
    }

ssss# If it's a fatal error, exit the program.
ssssif ($fatal) { exit; }

ssssreturn 1;
}

# Warn subroutine.
sub awarn
{
ssssmy ($lvl, $msg) = @_;

ssss# Check for an invalid level.
ssssif ($lvl =~ m/[^0-9]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
ssss	return;
ssss}

ssss# Level 1: Print to screen.
ssssif ($lvl >= 1) {
ssss    say "WARNING: $msg";
ssss}
ssss# Level 2: Log to file.
ssssif ($lvl >= 2) {
ssss	API::Log::alog("WARNING: $msg");
ssss}
    # Level 3: Log to IRC.
    if ($lvl >= 3) {
        API::Log::slog("WARNING: $msg");
    }

ssssreturn 1;
}


1;
# vim: set ai sw=4 ts=4:
