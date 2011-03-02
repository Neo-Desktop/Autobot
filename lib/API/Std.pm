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
    				cmd_del hook_add hook_del rchook_add rchook_del match_user
    				has_priv mod_exists ratelimit_check fpfmt);


# Initialize a module.
sub mod_init
{
    my ($name, $author, $version, $autover, $pkg) = @_;

    # Log/debug.
    API::Log::dbug('MODULES: Attempting to load '.$name.' (version '.$version.') by '.$author.'...');
    API::Log::alog('MODULES: Attempting to load '.$name.' (version '.$version.') by '.$author.'...');
    if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Attempting to load '.$name.' (version '.$version.') by '.$author.'...'); }

    # Check if this module is compatible with this version of Auto.
    if ($autover !~ m/^3\.0\.0a(7)$/xsm) {
    	API::Log::dbug('MODULES: Failed to load '.$name.': Incompatible with your version of Auto.');
    	API::Log::alog('MODULES: Failed to load '.$name.': Incompatible with your version of Auto.');
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Failed to load '.$name.': Incompatible with your version of Auto.'); }
    	return;
    }

    # Run the module's _init sub.
    my $mi = eval($pkg.'::_init();'); ## no critic qw(BuiltinFunctions::ProhibitStringyEval)

    if ($mi) {
    	# If successful, add to hash.
    	$MODULE{$name}{name}    = $name;
    	$MODULE{$name}{version} = $version;
    	$MODULE{$name}{author}  = $author;
    	$MODULE{$name}{pkg}     = $pkg;

    	API::Log::dbug('MODULES: '.$name.' successfully loaded.');
    	API::Log::alog('MODULES: '.$name.' successfully loaded.');
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: '.$name.' successfully loaded.'); }

    	return 1;
    }
    else {
    	# Otherwise, return a failed to load message.
    	API::Log::dbug('MODULES: Failed to load '.$name.q{.});
    	API::Log::alog('MODULES: Failed to load '.$name.q{.});
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Failed to load '.$name.q{.}); }

    	return;
    }
}

# Check if a module exists.
sub mod_exists
{
    my ($name) = @_;

    if (defined $API::Std::MODULE{$name}) { return 1; }

    return;
}

# Void a module.
sub mod_void
{
    my ($module) = @_;

    # Log/debug.
    API::Log::dbug('MODULES: Attempting to unload module: '.$module.'...');
    API::Log::alog('MODULES: Attempting to unload module: '.$module.'...');
    if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Attempting to unload module: '.$module.'...'); }

    # Check if this module exists.
    if (!defined $MODULE{$module}) {
    	API::Log::dbug('MODULES: Failed to unload '.$module.'. No such module?');
    	API::Log::alog('MODULES: Failed to unload '.$module.'. No such module?');
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Failed to unload '.$module.'. No such module?'); }
    	return;
    }

    # Run the module's _void sub.
    my $mi = eval($MODULE{$module}{pkg}.'::_void();'); ## no critic qw(BuiltinFunctions::ProhibitStringyEval)

    if ($mi) {
    	# If successful, delete class from program and delete module from hash.
    	Class::Unload->unload($MODULE{$module}{pkg});
    	delete $MODULE{$module};
    	API::Log::dbug('MODULES: Successfully unloaded '.$module.q{.});
    	API::Log::alog('MODULES: Successfully unloaded '.$module.q{.});
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Successfully unloaded '.$module.q{.}); }
    	return 1;
    }
    else {
    	# Otherwise, return a failed to unload message.
    	API::Log::dbug('MODULES: Failed to unload '.$module.q{.});
    	API::Log::alog('MODULES: Failed to unload '.$module.q{.});
        if (keys %Auto::SOCKET) { API::Log::slog('MODULES: Failed to unload '.$module.q{.}); }
    	return;
    }
}

# Add a command to Auto.
sub cmd_add
{
    my ($cmd, $lvl, $priv, $help, $sub) = @_;
    $cmd = uc $cmd;

    if (defined $API::Std::CMDS{$cmd}) { return; }
    if ($lvl =~ m/[^0-3]/sm) { return; } ## no critic qw(RegularExpressions::RequireExtendedFormatting)

    $API::Std::CMDS{$cmd}{lvl}   = $lvl;
    $API::Std::CMDS{$cmd}{help}  = $help;
    $API::Std::CMDS{$cmd}{priv}  = $priv;
    $API::Std::CMDS{$cmd}{'sub'} = $sub;

    return 1;
}


# Delete a command from Auto.
sub cmd_del
{
    my ($cmd) = @_;
    $cmd = uc $cmd;

    if (defined $API::Std::CMDS{$cmd}) {
    	delete $API::Std::CMDS{$cmd};
    }
    else {
    	return;
    }

    return 1;
}

# Add an event to Auto.
sub event_add
{
    my ($name) = @_;

    if (!defined $EVENTS{lc $name}) {
    	$EVENTS{lc $name} = 1;
    	return 1;
    }
    else {
    	API::Log::dbug('DEBUG: Attempt to add a pre-existing event ('.lc $name.')! Ignoring...');
    	return;
    }
}

# Delete an event from Auto.
sub event_del
{
    my ($name) = @_;

    if (defined $EVENTS{lc $name}) {
    	delete $EVENTS{lc $name};
    	delete $HOOKS{lc $name};
    	return 1;
    }
    else {
    	API::Log::dbug('DEBUG: Attempt to delete a non-existing event ('.lc $name.')! Ignoring...');
    	return;
    }
}

# Trigger an event.
sub event_run
{
    my ($event, @args) = @_;

    if (defined $EVENTS{lc $event} and defined $HOOKS{lc $event}) {
    	foreach my $hk (keys %{ $HOOKS{lc $event} }) {
    		my $ri = &{ $HOOKS{lc $event}{$hk} }(@args);
            if ($ri == -1) { last; }
    	}
    }

    return 1;
}

# Add a hook to Auto.
sub hook_add
{
    my ($event, $name, $sub) = @_;

    if (!defined $API::Std::HOOKS{lc $name}) {
    	if (defined $API::Std::EVENTS{lc $event}) {
    		$API::Std::HOOKS{lc $event}{lc $name} = $sub;
    		return 1;
    	}
    	else {
    		return;
    	}
    }
    else {
    	return;
    }
}

# Delete a hook from Auto.
sub hook_del
{
    my ($event, $name) = @_;

    if (defined $API::Std::HOOKS{lc $event}{lc $name}) {
    	delete $API::Std::HOOKS{lc $event}{lc $name};
    	return 1;
    }
    else {
    	return;
    }
}

# Add a timer to Auto.
sub timer_add
{
    my ($name, $type, $time, $sub) = @_;
    $name = lc $name;

    # Check for invalid type/time.
    if ($type =~ m/[^1-2]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
    	return;
    }
    if ($time =~ m/[^0-9]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
    	return;
    }

    if (!defined $Auto::TIMERS{$name}) {
    	$Auto::TIMERS{$name}{type} = $type;
    	$Auto::TIMERS{$name}{time} = time + $time;
    	if ($type == 2) { $Auto::TIMERS{$name}{secs} = $time; }
    	$Auto::TIMERS{$name}{sub}  = $sub;
    	return 1;
    }

    return 1;
}

# Delete a timer from Auto.
sub timer_del
{
    my ($name) = @_;
    $name = lc $name;

    if (defined $Auto::TIMERS{$name}) {
    	delete $Auto::TIMERS{$name};
    	return 1;
    }

    return;
}

# Hook onto a raw command.
sub rchook_add
{
    my ($cmd, $sub) = @_;
    $cmd = uc $cmd;

    if (defined $Proto::IRC::RAWC{$cmd}) { return; }

    $Proto::IRC::RAWC{$cmd} = $sub;

    return 1;
}

# Delete a raw command hook.
sub rchook_del
{
    my ($cmd) = @_;
    $cmd = uc $cmd;

    if (!defined $Proto::IRC::RAWC{$cmd}) { return; }

    delete $Proto::IRC::RAWC{$cmd};

    return 1;
}

# Configuration value getter.
sub conf_get
{
    my ($value) = @_;

    # Create an array out of the value.
    my @val;
    if ($value =~ m/:/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
    	@val = split m/[:]/sm, $value; ## no critic qw(RegularExpressions::RequireExtendedFormatting)
    }
    else {
    	@val = ($value);
    }
    # Undefine this as it's unnecessary now.
    undef $value;

    # Get the count of elements in the array.
    my $count = scalar @val;

    # Return the requested configuration value(s).
    if ($count == 1) {
    	if (ref $Auto::SETTINGS{$val[0]} eq 'HASH') {
    		return %{ $Auto::SETTINGS{$val[0]} };
    	}
    	else {
    		return $Auto::SETTINGS{$val[0]};
    	}
    }
    elsif ($count == 2) {
    	if (ref $Auto::SETTINGS{$val[0]}{$val[1]} eq 'HASH') {
    		return %{ $Auto::SETTINGS{$val[0]}{$val[1]} };
    	}
    	else {
    		return $Auto::SETTINGS{$val[0]}{$val[1]};
    	}
    }
    elsif ($count == 3) {
    	if (ref $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]} eq 'HASH') {
    		return %{ $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]} };
    	}
    	else {
    		return $Auto::SETTINGS{$val[0]}{$val[1]}{$val[2]};
    	}
    }
    else {
    	return;
    }
}

# Translation subroutine.
sub trans
{
    my $id = shift;
    $id =~ s/ /_/gsm;

    if (defined $API::Std::LANGE{$id}) {
    	return sprintf $API::Std::LANGE{$id}, @_;
    }
    else {
    	$id =~ s/_/ /gsm;
    	return $id;
    }
}

# Match user subroutine.
sub match_user
{
    my (%user) = @_;

    # Get data from config.
    if (!conf_get('user')) { return; }
    my %uhp = conf_get('user');

    foreach my $userkey (keys %uhp) {
    	# For each user block.
    	my %ulhp = %{ $uhp{$userkey} };
    	foreach my $uhk (keys %ulhp) {
            # For each user.

    		if ($uhk eq 'net') {
                if (defined $user{svr}) {
                    if (lc $user{svr} ne lc(($ulhp{$uhk})[0][0])) {
                        # config.user:net conflicts with irc.user:svr.
                        last;
                    }
                }
            }
            elsif ($uhk eq 'mask') {
    			# Put together the user information.
    			my $mask = $user{nick}.q{!}.$user{user}.q{@}.$user{host};
    			if (API::IRC::match_mask($mask, ($ulhp{$uhk})[0][0])) {
    				# We've got a host match.
    				return $userkey;
    			}
    		}
            elsif ($uhk eq 'chanstatus' and defined $ulhp{'net'}) {
                my ($ccst, $ccnm) = split m/[:]/sm, ($ulhp{$uhk})[0][0]; ## no critic qw(RegularExpressions::RequireExtendedFormatting)
                my $svr = $ulhp{net}[0];
                if (defined $Auto::SOCKET{$svr}) {
                    if ($ccnm eq 'CURRENT' and defined $user{chan}) {
                        if (defined $Proto::IRC::chanusers{$svr}{$user{chan}}{$user{nick}}) {
                            if ($Proto::IRC::chanusers{$svr}{$user{chan}}{$user{nick}} =~ m/($ccst)/sm) { return $userkey; } ## no critic qw(RegularExpressions::RequireExtendedFormatting)
                        }
                    }
                    else {
                        foreach my $bcj (keys %{ $Proto::IRC::botchans{$svr} }) {
                            if (API::IRC::match_mask($bcj, $ccnm)) {
                                if (defined $Proto::IRC::chanusers{$svr}{$bcj}{$user{nick}}) {
                                    if ($Proto::IRC::chanusers{$svr}{$bcj}{$user{nick}} =~ m/($ccst)/sm) { return $userkey; } ## no critic qw(RegularExpressions::RequireExtendedFormatting)
                                }
                            }
                        }
                    }
                }
            }
    	}
    }

    return;
}

# Privilege subroutine.
sub has_priv
{
    my ($cuser, $cpriv) = @_;

    if (conf_get("user:$cuser:privs")) {
    	my $cups = (conf_get("user:$cuser:privs"))[0][0];

    	if (defined $Auto::PRIVILEGES{$cups}) {
    		foreach (@{ $Auto::PRIVILEGES{$cups} }) {
    			if ($_ eq $cpriv or $_ eq 'ALL') { return 1; }
    		}
    	}
    }

    return;
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
    my ($lvl, $msg, $fatal) = @_;

    # Check for an invalid level.
    if ($lvl =~ m/[^0-9]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
    	return;
    }
    if ($fatal =~ m/[^0-1]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
    	return;
    }

    # Level 1: Print to screen.
    if ($lvl >= 1) {
    	say "ERROR: $msg";
    }
    # Level 2: Log to file.
    if ($lvl >= 2) {
    	API::Log::alog("ERROR: $msg");
    }
    # Level 3: Log to IRC.
    if ($lvl >= 3) {
        API::Log::slog("ERROR: $msg");
    }

    # If it's a fatal error, exit the program.
    if ($fatal) {
        API::Std::event_run('on_shutdown');
        exit; 
    }

    return 1;
}

# Warn subroutine.
sub awarn
{
    my ($lvl, $msg) = @_;

    # Check for an invalid level.
    if ($lvl =~ m/[^0-9]/sm) { ## no critic qw(RegularExpressions::RequireExtendedFormatting)
    	return;
    }

    # Level 1: Print to screen.
    if ($lvl >= 1) {
        say "WARNING: $msg";
    }
    # Level 2: Log to file.
    if ($lvl >= 2) {
    	API::Log::alog("WARNING: $msg");
    }
    # Level 3: Log to IRC.
    if ($lvl >= 3) {
        API::Log::slog("WARNING: $msg");
    }

    return 1;
}

# Formatting a file path.
sub fpfmt {
    my ($path) = @_;

    if ($path =~ m/\s/xsm) { return "\"$path\""; }
    else { return $path; }
}


1;
# vim: set ai et sw=4 ts=4:
