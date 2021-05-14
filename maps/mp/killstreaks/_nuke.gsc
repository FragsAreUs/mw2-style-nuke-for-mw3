
init()
{
    precacheitem( "nuke_mp" );
    precachelocationselector( "map_nuke_selector" );
    precachestring( &"MP_TACTICAL_NUKE_CALLED" );
    precachestring( &"MP_FRIENDLY_TACTICAL_NUKE" );
    precachestring( &"MP_TACTICAL_NUKE" );

    level.nukeVisionSet = "aftermath";

    level._effect["nuke_player"] = loadfx( "explosions/player_death_nuke" );
    level._effect["nuke_flash"] = loadfx( "explosions/player_death_nuke_flash" );
    level._effect["nuke_aftermath"] = loadfx( "dust/nuke_aftermath_mp" );

    game["strings"]["nuclear_strike"] = &"MP_TACTICAL_NUKE";

    level.killstreakFuncs["nuke"] = ::tryUseNuke;

    setdvarifuninitialized( "scr_nukeTimer", 10 );
    setdvarifuninitialized( "scr_nukeCancelMode", 0 );

    level.nukeTimer = getdvarint( "scr_nukeTimer" );
    level.cancelMode = getdvarint( "scr_nukeCancelMode" );

    /#
	setDevDvarIfUninitialized( "scr_nukeDistance", 5000 );
	setDevDvarIfUninitialized( "scr_nukeDebugPosition", 0 );
	#/

    setDevDvarIfUninitialized( "scr_nukeEndsGame", 0 );

    //level thread nuke_EMPTeamTracker();
    level thread onPlayerConnect();
}

tryUseNuke( lifeId, allowCancel )
{
    if ( isdefined( level.nukeIncoming ) )
    {
        self iprintlnbold( &"MP_NUKE_ALREADY_INBOUND" );
        return 0;
    }

    if ( maps\mp\_utility::isUsingRemote() && (!isdefined( level.gtnw ) || !level.gtnw) )
        return 0;

	if ( !isDefined( allowCancel ) )
		allowCancel = true;

	self thread doNuke( allowCancel );
    self notify( "used_nuke" );

    return true;
}

delaythread_nuke( delay, func )
{
    level endon( "nuke_cancelled" );

    wait ( delay );

    thread [[ func ]]();
}

doNuke( allowCancel )
{
    level endon( "nuke_cancelled" );

    level.nukeInfo = spawnStruct();
    level.nukeInfo.player = self;
    level.nukeInfo.team = self.pers["team"];

    level.nukeIncoming = true;

    setdvar( "ui_bomb_timer", 4 );

    if ( level.teamBased )
        thread maps\mp\_utility::teamPlayerCardSplash( "used_nuke", self, self.team );
    else if ( !level.hardcoreMode )
        self iprintlnbold( &"MP_FRIENDLY_TACTICAL_NUKE" );

    level thread delaythread_nuke( level.nukeTimer - 3.3, ::nukeSoundIncoming );
    level thread delaythread_nuke( level.nukeTimer, ::nukeSoundExplosion );
    level thread delaythread_nuke( level.nukeTimer, ::nukeSlowMo );
    level thread delaythread_nuke( level.nukeTimer, ::nukeEffects );
    level thread delaythread_nuke( level.nukeTimer + 0.25, ::nukeVision );
    level thread delaythread_nuke( level.nukeTimer + 1.5, ::nukeDeath );
    level thread delaythread_nuke( level.nukeTimer + 1.5, ::nukeEarthquake );
    level thread nukeAftermathEffect();
    level thread update_ui_timers();

    if ( level.cancelMode && allowCancel )
        level thread cancelNukeOnDeath( self );

    // leaks if lots of nukes are called due to endon above.
    if ( !isdefined( level.nuke_clockobject ) )
    {
        level.nuke_clockobject = spawn( "script_origin", ( 0, 0, 0 ) );
        level.nuke_clockobject hide();
    }

    if ( !isdefined( level.nuke_soundobject ) )
    {
        level.nuke_soundobject = spawn( "script_origin", ( 0, 0, 1 ) );
        level.nuke_soundobject hide();
    }

    for ( var_1 = level.nukeTimer; var_1 > 0; var_1-- )
    {
        level.nuke_clockobject playsound( "ui_mp_nukebomb_timer" );
        wait 1;
    }
}

cancelNukeOnDeath( player )
{
    player common_scripts\utility::waittill_any( "death", "disconnect" );

    if ( isdefined( player ) && level.cancelMode == 2 )
        player thread maps\mp\killstreaks\_emp::EMP_Use( 0, 0 );

    maps\mp\gametypes\_gamelogic::resumeTimer();
	level.timeLimitOverride = 0;

    setdvar( "ui_bomb_timer", 0 );

    level notify( "nuke_cancelled" );
}

nukeSoundIncoming()
{
    level endon( "nuke_cancelled" );

    if ( isdefined( level.nuke_soundobject ) )
        level.nuke_soundobject playsound( "nuke_incoming" );
}

nukeSoundExplosion()
{
    level endon( "nuke_cancelled" );

    if ( isdefined( level.nuke_soundobject ) )
    {
        level.nuke_soundobject playsound( "nuke_explosion" );
        level.nuke_soundobject playsound( "nuke_wave" );
    }
}

nukeEffects()
{
    level endon( "nuke_cancelled" );

    setdvar( "ui_bomb_timer", 0 );
    setGameEndTime( 0 );

	level.nukeDetonated = true;

    foreach ( player in level.players )
    {
        playerForward = anglestoforward( player.angles );
        playerForward = ( playerForward[0], playerForward[1], 0 );
        playerForward = vectornormalize( playerForward );

        nukeDistance = 5000;
        /# nukeDistance = getDvarInt( "scr_nukeDistance" );	#/

        nukeEnt = spawn( "script_model", player.origin + playerForward * nukeDistance );
        nukeEnt setmodel( "tag_origin" );
        nukeEnt.angles = ( 0, player.angles[1] + 180, 90 );

		/#
		if ( getDvarInt( "scr_nukeDebugPosition" ) )
		{
			lineTop = ( nukeEnt.origin[0], nukeEnt.origin[1], (nukeEnt.origin[2] + 500) );
			thread draw_line_for_time( nukeEnt.origin, lineTop, 1, 0, 0, 10 );
		}
		#/

        nukeEnt thread nukeEffect( player );
        player.nuked = true;


    }
}

nukeEffect( player )
{
	level endon ( "nuke_cancelled" );

	player endon( "disconnect" );

    common_scripts\utility::waitframe();
    playfxontagforclients( level._effect["nuke_flash"], self, "tag_origin", player );
}

nukeAftermathEffect()
{
    level endon( "nuke_cancelled" );

    level waittill( "spawning_intermission" );

    afermathEnt = getentarray( "mp_global_intermission", "classname" );
    afermathEnt = afermathEnt[0];
    var_1 = anglestoup( afermathEnt.angles );
    var_2 = anglestoright( afermathEnt.angles );

    playfx( level._effect["nuke_aftermath"], afermathEnt.origin, var_1, var_2 );
}

nukeSlowMo()
{
	level endon ( "nuke_cancelled" );

	//SetSlowMotion( <startTimescale>, <endTimescale>, <deltaTime> )
	setSlowMotion( 1.0, 0.25, 0.5 );
	level waittill( "nuke_death" );
	setSlowMotion( 0.25, 1, 2.0 );
}

nukeVision()
{
    level endon( "nuke_cancelled" );

    level.nukeVisionInProgress = 1;

    visionsetnaked( "mpnuke", 3 );

    level waittill( "nuke_death" );

    visionsetnaked( level.nukeVisionSet, 5 );
    visionsetpain( level.nukeVisionSet );
    wait 5;
	level.nukeVisionInProgress = undefined;
}

nukeDeath()
{
    level endon( "nuke_cancelled" );

    level notify( "nuke_death" );

    //maps\mp\gametypes\_hostmigration::waitTillHostMigrationDone();

    ambientstop( 1 );

 	foreach( player in level.players )
	{
		if ( isAlive( player ) )
			player thread maps\mp\gametypes\_damage::finishPlayerDamageWrapper( level.nukeInfo.player, level.nukeInfo.player, 999999, 0, "MOD_EXPLOSIVE", "nuke_mp", player.origin, player.origin, "none", 0, 0 );
	}

    level.postRoundTime = 10;

	nukeEndsGame = true;

    //level thread nuke_EMPJam();

    if ( level.teamBased )
		thread maps\mp\gametypes\_gamelogic::endGame( level.nukeInfo.team, game["strings"]["nuclear_strike"], true );
	else
	{
		if ( isDefined( level.nukeInfo.player ) )
			thread maps\mp\gametypes\_gamelogic::endGame( level.nukeInfo.player, game["strings"]["nuclear_strike"], true );
		else
			thread maps\mp\gametypes\_gamelogic::endGame( level.nukeInfo, game["strings"]["nuclear_strike"], true );
	}

    //level.nukeIncoming = undefined;
}

nukeEarthquake()
{
    level endon( "nuke_cancelled" );

    level waittill( "nuke_death" );
}

waitForNukeCancel()
{
	self waittill( "cancel_location" );
	self setblurforplayer( 0, 0.3 );
}

endSelectionOn( waitfor )
{
	self endon( "stop_location_selection" );
	self waittill( waitfor );
	self thread stopNukeLocationSelection( (waitfor == "disconnect") );
}

endSelectionOnGameEnd()
{
	self endon( "stop_location_selection" );
	level waittill( "game_ended" );
	self thread stopNukeLocationSelection( 0 );
}

stopNukeLocationSelection( disconnected )
{
	if ( !disconnected )
	{
		self setblurforplayer( 0, 0.3 );
		self endLocationSelection();
		self.selectingLocation = undefined;
	}
	self notify( "stop_location_selection" );
}


// nuke_EMPJam()
// {
//     level endon( "game_ended" );
//     level maps\mp\killstreaks\_emp::destroyActiveVehicles( level.nukeInfo.player, maps\mp\_utility::getOtherTeam( level.nukeInfo.team ) );
//     level notify( "nuke_EMPJam" );
//     level endon( "nuke_EMPJam" );

//     if ( level.teamBased )
//         level.teamNukeEMPed[maps\mp\_utility::getOtherTeam( level.nukeInfo.team )] = 1;
//     else
//     {
//         level.teamNukeEMPed[level.nukeInfo.team] = 1;
//         level.teamNukeEMPed[maps\mp\_utility::getOtherTeam( level.nukeInfo.team )] = 1;
//     }

//     level notify( "nuke_emp_update" );
//     level thread keepNukeEMPTimeRemaining();
//     maps\mp\gametypes\_hostmigration::waitLongDurationWithHostMigrationPause( level.nukeEmpTimeout );

//     if ( level.teamBased )
//         level.teamNukeEMPed[maps\mp\_utility::getOtherTeam( level.nukeInfo.team )] = 0;
//     else
//     {
//         level.teamNukeEMPed[level.nukeInfo.team] = 0;
//         level.teamNukeEMPed[maps\mp\_utility::getOtherTeam( level.nukeInfo.team )] = 0;
//     }

//     foreach ( var_1 in level.players )
//     {
//         if ( level.teamBased && var_1.team == level.nukeInfo.team )
//             continue;

//         var_1.nuked = undefined;
//     }

//     level notify( "nuke_emp_update" );
//     level notify( "nuke_emp_ended" );
// }

// keepNukeEMPTimeRemaining()
// {
//     level notify( "keepNukeEMPTimeRemaining" );
//     level endon( "keepNukeEMPTimeRemaining" );
//     level endon( "nuke_emp_ended" );

//     for ( level.nukeEmpTimeRemaining = int( level.nukeEmpTimeout ); level.nukeEmpTimeRemaining; level.nukeEmpTimeRemaining-- )
//         wait 1;
// }

// nuke_EMPTeamTracker()
// {
//     level endon( "game_ended" );

//     for (;;)
//     {
//         level common_scripts\utility::waittill_either( "joined_team", "nuke_emp_update" );

//         foreach ( var_1 in level.players )
//         {
//             if ( var_1.team == "spectator" )
//                 continue;

//             if ( level.teamBased )
//             {
//                 if ( isdefined( level.nukeInfo.team ) && var_1.team == level.nukeInfo.team )
//                     continue;
//             }
//             else if ( isdefined( level.nukeInfo.player ) && var_1 == level.nukeInfo.player )
//                 continue;

//             if ( !level.teamNukeEMPed[var_1.team] && !var_1 maps\mp\_utility::isEMPed() )
//             {
//                 var_1 setempjammed( 0 );
//                 continue;
//             }

//             var_1 setempjammed( 1 );
//         }
//     }
// }

onPlayerConnect()
{
    for (;;)
    {
        level waittill( "connected",  var_0  );
        var_0 thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    self endon( "disconnect" );

    for (;;)
    {
        self waittill( "spawned_player" );

        if ( isdefined( level.nukeDetonated ) )
            self visionsetnakedforplayer( level.nukeVisionSet, 0 );
    }
}

update_ui_timers()
{
    level endon( "game_ended" );
    level endon( "disconnect" );
    level endon( "nuke_cancelled" );
    level endon( "nuke_death" );
    var_0 = level.nukeTimer * 1000 + gettime();
    setdvar( "ui_nuke_end_milliseconds", var_0 );
    level waittill( "host_migration_begin" );
    var_1 = maps\mp\gametypes\_hostmigration::waitTillHostMigrationDone();

    if ( var_1 > 0 )
        setdvar( "ui_nuke_end_milliseconds", var_0 + var_1 );
}
