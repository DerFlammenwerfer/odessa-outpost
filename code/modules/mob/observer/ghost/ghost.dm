var/global/list/image/ghost_darkness_images = list() //this is a list of images for things ghosts should still be able to see when they toggle darkness
var/global/list/image/ghost_sightless_images = list() //this is a list of images for things ghosts should still be able to see even without ghost sight

/mob/observer/ghost
	name = "ghost"
	desc = "It's a g-g-g-g-ghooooost!" //jinkies!
	icon = 'icons/mob/mob.dmi'
	icon_state = "ghost"
	canmove = 0
	blinded = 0
	anchored = 1	//  don't get pushed around
	layer = GHOST_LAYER
	movement_handlers = list(/datum/movement_handler/mob/incorporeal)

	var/can_reenter_corpse
	var/datum/hud/living/carbon/hud = null // hud
	var/bootime = 0
	var/started_as_observer //This variable is set to 1 when you enter the game as an observer.
							//If you died in the game and are a ghsot - this will remain as null.
							//Note that this is not a reliable way to determine if admins started as observers, since they change mobs a lot.
	var/has_enabled_antagHUD = 0
	var/medHUD = 0
	var/antagHUD = 0
	universal_speak = 1
	var/atom/movable/following = null
	var/admin_ghosted = 0
	var/anonsay = 0
	var/ghostvision = 1 //is the ghost able to see things humans can't?
	var/seedarkness = 1

	var/obj/item/weapon/tool/multitool/ghost_multitool
	incorporeal_move = 1

/mob/observer/ghost/New(mob/body)

	see_in_dark = 100
	verbs += /mob/observer/ghost/proc/dead_tele

	if(ismob(body))
		var/turf/T = get_turf(body)				//Where is the body located?
		attack_log = body.attack_log	//preserve our attack logs by copying them to our ghost

		if (ishuman(body))
			var/mob/living/carbon/human/H = body
			icon = H.stand_icon
			overlays = H.overlays_standing
		else
			icon = body.icon
			icon_state = body.icon_state
			overlays = body.overlays

		alpha = 127

		gender = body.gender
		if(body.mind && body.mind.name)
			name = body.mind.name
		else
			if(body.real_name)
				name = body.real_name
			else
				if(gender == MALE)
					name = capitalize(pick(GLOB.first_names_male)) + " " + capitalize(pick(GLOB.last_names))
				else
					name = capitalize(pick(GLOB.first_names_female)) + " " + capitalize(pick(GLOB.last_names))

		mind = body.mind	//we don't transfer the mind but we keep a reference to it.
		forceMove(T)
	else
		//Safety in case we cannot find the body's position
		var/turf/T = pick_spawn_location("Observer")
		if(istype(T))
			src.forceMove(T)

	if(!name)							//To prevent nameless ghosts
		name = capitalize(pick(GLOB.first_names_male)) + " " + capitalize(pick(GLOB.last_names))
	real_name = name

	ghost_multitool = new(src)
	..()

/mob/observer/ghost/Destroy()
	stop_following()
	qdel(ghost_multitool)
	ghost_multitool = null
	return ..()

/mob/observer/ghost/Topic(href, href_list)
	if (href_list["track"])
		if(istype(href_list["track"],/mob))
			var/mob/target = locate(href_list["track"]) in SSmobs.mob_list
			if(target)
				ManualFollow(target)
		else
			var/atom/target = locate(href_list["track"])
			if(istype(target))
				ManualFollow(target)

/*
Transfer_mind is there to check if mob is being deleted/not going to have a body.
Works together with spawning an observer, noted above.
*/

/mob/observer/ghost/Life()
	..()
	if(!loc) return
	if(!client) return 0

	if(client.images.len)
		for(var/image/hud in client.images)
			if(copytext(hud.icon_state,1,4) == "hud")
				client.images.Remove(hud)

	if(antagHUD)
		var/list/target_list = list()
		for(var/mob/living/target in oview(src, 14))
			if(target.mind && target.mind.antagonist.len != 0)
				target_list += target
		if(target_list.len)
			assess_targets(target_list, src)
	if(medHUD)
		process_medHUD(src)


/mob/observer/ghost/proc/process_medHUD(var/mob/M)
	var/client/C = M.client
	for(var/mob/living/carbon/human/patient in oview(M, 14))
		C.images += patient.hud_list[HEALTH_HUD]
		C.images += patient.hud_list[STATUS_HUD_OOC]

/mob/observer/ghost/proc/assess_targets(list/target_list, mob/observer/ghost/U)
	var/client/C = U.client
	for(var/mob/living/carbon/human/target in target_list)
		C.images += target.hud_list[SPECIALROLE_HUD]
	for(var/mob/living/silicon/target in target_list)
		C.images += target.hud_list[SPECIALROLE_HUD]
	return 1

/mob/proc/ghostize(var/can_reenter_corpse = 1)
	if(key)
		if(client)
			client.destroy_UI()
		var/mob/observer/ghost/ghost = new(src)	//Transfer safety to observer spawning proc.
		ghost.can_reenter_corpse = can_reenter_corpse
		ghost.timeofdeath = src.stat == DEAD ? src.timeofdeath : world.time
			//This is duplicated for robustness in cases where death might not be called.
		//It is also set in the mob/death proc
		// One more if to get rid off re-enter timer resets.
		if(stat != DEAD)
			if (isanimal(src))
				set_death_time(ANIMAL, world.time)
			else if (ispAI(src) || isdrone(src))
				set_death_time(MINISYNTH, world.time)
			else
				set_death_time(CREW, world.time)//Crew is the fallback

		//Set the respawn bonus from ghosting while in cryosleep.
		//This is duplicated in the cryopod code for robustness. The message will not display twice
		if (istype(loc, /obj/machinery/cryopod) && in_perfect_health())
			if (!get_respawn_bonus("CRYOSLEEP"))
				src << SPAN_NOTICE("Because you ghosted from a cryopod in good health, your crew respawn time has been reduced by [CRYOPOD_SPAWN_BONUS_DESC].")
				src << 'sound/effects/magic/blind.ogg' //Play this sound to a player whenever their respawn time gets reduced
			set_respawn_bonus("CRYOSLEEP", CRYOPOD_SPAWN_BONUS)

		ghost.ckey = ckey
		ghost.client = client
		ghost.initialise_postkey()
		if(ghost.client && !ghost.client.holder && !config.antag_hud_allowed)		// For new ghosts we remove the verb from even showing up if it's not allowed.
			ghost.verbs -= /mob/observer/ghost/verb/toggle_antagHUD	// Poor guys, don't know what they are missing!

		return ghost

/*
This is the proc mobs get to turn into a ghost. Forked from ghostize due to compatibility issues.
*/
/mob/living/verb/ghost()
	set category = "OOC"
	set name = "Ghost"
	set desc = "Relinquish your life and enter the land of the dead."

	if(stat == DEAD)
		announce_ghost_joinleave(ghostize(1))
	else
		var/response
		if(src.client && src.client.holder)
			response = alert(src, "You have the ability to Admin-Ghost. The regular Ghost verb will announce your presence to dead chat. Both variants will allow you to return to your body using 'aghost'.\n\nWhat do you wish to do?", "Are you sure you want to ghost?", "Ghost", "Admin Ghost", "Stay in body")
			if(response == "Admin Ghost")
				if(!src.client)
					return
				src.client.admin_ghost()
		else
			response = alert(src, "Are you -sure- you want to ghost?\n(You are alive. If you ghost, you won't be able to play this round for another 30 minutes! You can't change your mind so choose wisely!)", "Are you sure you want to ghost?", "Ghost", "Stay in body")
		if(response != "Ghost")
			return
		resting = 1
		var/turf/location = get_turf(src)
		message_admins("[key_name_admin(usr)] has ghosted. (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[location.x];Y=[location.y];Z=[location.z]'>JMP</a>)")
		log_game("[key_name_admin(usr)] has ghosted.")
		var/mob/observer/ghost/ghost = ghostize(0)	//0 parameter is so we can never re-enter our body, "Charlie, you can never come baaaack~" :3
		ghost.timeofdeath = world.time // Because the living mob won't have a time of death and we want the respawn timer to work properly.
		announce_ghost_joinleave(ghost)

/mob/observer/ghost/can_use_hands()	return 0
/mob/observer/ghost/is_active()		return 0

/mob/observer/ghost/Stat()
	. = ..()
	if(statpanel("Status"))
		if(evacuation_controller)
			var/eta_status = evacuation_controller.get_status_panel_eta()
			if(eta_status)
				stat(null, eta_status)

/mob/observer/ghost/verb/reenter_corpse()
	set category = "Ghost"
	set name = "Re-enter Corpse"
	if(!client)	return
	client.destroy_UI()

	if(!(mind && mind.current && can_reenter_corpse))
		src << "<span class='warning'>You have no body.</span>"
		return
	if(mind.current.key && copytext(mind.current.key,1,2)!="@")	//makes sure we don't accidentally kick any clients
		usr << "<span class='warning'>Another consciousness is in your body... it is resisting you.</span>"
		return
	stop_following()
	mind.current.ajourn=0
	mind.current.key = key
	mind.current.teleop = null
	if(!admin_ghosted)
		announce_ghost_joinleave(mind, 0, "They now occupy their body again.")
	return 1

/mob/observer/ghost/verb/toggle_medHUD()
	set category = "Ghost"
	set name = "Toggle MedicHUD"
	set desc = "Toggles Medical HUD allowing you to see how everyone is doing"
	if(!client)
		return
	if(medHUD)
		medHUD = 0
		src << "\blue <B>Medical HUD Disabled</B>"
	else
		medHUD = 1
		src << "\blue <B>Medical HUD Enabled</B>"

/mob/observer/ghost/verb/toggle_antagHUD()
	set category = "Ghost"
	set name = "Toggle AntagHUD"
	set desc = "Toggles AntagHUD allowing you to see who is the antagonist"

	if(!client)
		return
	var/mentor = is_mentor(usr.client)
	if(!config.antag_hud_allowed && (!client.holder || mentor))
		src << "\red Admins have disabled this for this round."
		return
	var/mob/observer/ghost/M = src
	if(jobban_isbanned(M, "AntagHUD"))
		src << "\red <B>You have been banned from using this feature</B>"
		return
	if(config.antag_hud_restricted && !M.has_enabled_antagHUD && (!client.holder || mentor))
		var/response = alert(src, "If you turn this on, you will not be able to take any part in the round.","Are you sure you want to turn this feature on?","Yes","No")
		if(response == "No") return
		M.can_reenter_corpse = 0
	if(!M.has_enabled_antagHUD && (!client.holder || mentor))
		M.has_enabled_antagHUD = 1
	if(M.antagHUD)
		M.antagHUD = 0
		src << "\blue <B>AntagHUD Disabled</B>"
	else
		M.antagHUD = 1
		src << "\blue <B>AntagHUD Enabled</B>"

/mob/observer/ghost/proc/dead_tele(A in ghostteleportlocs)
	set category = "Ghost"
	set name = "Teleport"
	set desc= "Teleport to a location"
	if(!isghost(usr))
		usr << "Not when you're not dead!"
		return
	usr.verbs -= /mob/observer/ghost/proc/dead_tele
	spawn(30)
		usr.verbs += /mob/observer/ghost/proc/dead_tele
	var/area/thearea = ghostteleportlocs[A]
	if(!thearea)	return

	var/list/L = list()
	var/holyblock = 0

	if(usr.invisibility <= SEE_INVISIBLE_LIVING)
		for(var/turf/T in get_area_turfs(thearea.type))
			if(!T.holy)
				L+=T
			else
				holyblock = 1
	else
		for(var/turf/T in get_area_turfs(thearea.type))
			L+=T

	if(!L || !L.len)
		if(holyblock)
			usr << "<span class='warning'>This area has been entirely made into sacred grounds, you cannot enter it while you are in this plane of existence!</span>"
		else
			usr << "No area available."

	stop_following()
	usr.forceMove(pick(L))

/mob/observer/ghost/verb/follow(input in getmobs())
	set category = "Ghost"
	set name = "Follow" // "Haunt"
	set desc = "Follow and haunt a mob."

	var/target = getmobs()[input]
	if(!target) return
	ManualFollow(target)

// This is the ghost's follow verb with an argument
/mob/observer/ghost/proc/ManualFollow(var/atom/movable/target)
	if(!target || target == following || target == src)
		return

	stop_following()
	following = target
	GLOB.moved_event.register(following, src, /atom/movable/proc/move_to_turf)
	GLOB.dir_set_event.register(following, src, /atom/proc/recursive_dir_set)
	GLOB.destroyed_event.register(following, src, /mob/observer/ghost/proc/stop_following)

	src << "<span class='notice'>Now following \the [following]</span>"
	move_to_turf(following, following.loc, following.loc)

/mob/observer/ghost/proc/stop_following()
	if(following)
		src << "<span class='notice'>No longer following \the [following]</span>"
		GLOB.moved_event.unregister(following, src)
		GLOB.dir_set_event.unregister(following, src)
		GLOB.destroyed_event.unregister(following, src)
		following = null

// Makes the ghost cease following if the user has moved
/mob/observer/ghost/PostIncorporealMovement()
	stop_following()

/mob/observer/ghost/move_to_turf(var/atom/movable/am, var/old_loc, var/new_loc)
	var/turf/T = get_turf(new_loc)
	if(check_holy(T))
		usr << "<span class='warning'>You cannot follow something standing on holy grounds!</span>"
		return
	..()

/mob/proc/check_holy(var/turf/T)
	return 0

/mob/observer/ghost/check_holy(var/turf/T)
	if(check_rights(R_ADMIN|R_FUN, 0, src))
		return 0
	return (T && T.holy) && (invisibility <= SEE_INVISIBLE_LIVING)

/mob/observer/ghost/verb/jumptomob_ghost(target in getmobs()) //Moves the ghost instead of just changing the ghosts's eye -Nodrak
	set category = "Ghost"
	set name = "Jump to a Mob"
	set desc = "Teleport to a mob"

	if(isghost(usr)) //Make sure they're an observer!

		if (!target)//Make sure we actually have a target
			return
		else
			var/mob/M = getmobs()[target] //Destination mob
			var/turf/T = get_turf(M) //Turf of the destination mob

			if(T && isturf(T))	//Make sure the turf exists, then move the source to that destination.
				stop_following()
				forceMove(T)
			else
				src << "This mob is not located in the game world."
/*
/mob/observer/ghost/verb/boo()
	set category = "Ghost"
	set name = "Boo!"
	set desc= "Scare your crew members because of boredom!"

	if(bootime > world.time) return
	var/obj/machinery/light/L = locate(/obj/machinery/light) in view(1, src)
	if(L)
		L.flicker()
		bootime = world.time + 600
		return
	//Maybe in the future we can add more <i>spooky</i> code here!
	return
*/

/mob/observer/ghost/memory()
	set hidden = 1
	src << "\red You are dead! You have no mind to store memory!"

/mob/observer/ghost/add_memory()
	set hidden = 1
	src << "\red You are dead! You have no mind to store memory!"


/mob/observer/ghost/verb/analyze_air()
	set name = "Analyze Air"
	set category = "Ghost"

	if(!isghost(usr)) return

	// Shamelessly copied from the Gas Analyzers
	if (!( istype(usr.loc, /turf) ))
		return

	var/datum/gas_mixture/environment = usr.loc.return_air()

	var/pressure = environment.return_pressure()
	var/total_moles = environment.total_moles

	src << "\blue <B>Results:</B>"
	if(abs(pressure - ONE_ATMOSPHERE) < 10)
		src << "\blue Pressure: [round(pressure,0.1)] kPa"
	else
		src << "\red Pressure: [round(pressure,0.1)] kPa"
	if(total_moles)
		for(var/g in environment.gas)
			src << "\blue [gas_data.name[g]]: [round((environment.gas[g] / total_moles) * 100)]% ([round(environment.gas[g], 0.01)] moles)"
		src << "\blue Temperature: [round(environment.temperature-T0C,0.1)]&deg;C ([round(environment.temperature,0.1)]K)"
		src << "\blue Heat Capacity: [round(environment.heat_capacity(),0.1)]"


/mob/observer/verb/become_mouse()
	set name = "Respawn as mouse"
	set category = "Ghost"


	if(!MayRespawn(1, ANIMAL))
		return

	if(!BC_IsKeyAllowedToConnect(usr.ckey) && !usr.client.holder)
		usr  << SPAN_DANGER("Border Control is enabled, and you haven't been whitelisted!  You're welcome to observe, \
			    but in order to play, you'll need to be whitelisted!  Please visit our discord to submit an access request!")
		return

	var/turf/T = get_turf(src)
	if(!T || !(T.z in maps_data.station_levels))
		src << "<span class='warning'>You may not spawn as a mouse on this Z-level.</span>"
		return

	var/response = alert(src, "Are you -sure- you want to become a mouse? This will not affect your crew or drone respawn time. You can choose to spawn near your ghost or at a random vent on this deck.","Are you sure you want to squeek?","Near Ghost", "Random","Cancel")
	if(response == "Cancel") return  //Hit the wrong key...again.


	//find a viable mouse candidate
	var/mob/living/simple_animal/mouse/host
	var/obj/machinery/atmospherics/unary/vent_pump/spawnpoint
	if (response == "Random")
		spawnpoint = find_mouse_random_spawnpoint(T.z)
	else if (response == "Near Ghost")
		spawnpoint = find_mouse_near_spawnpoint(T)

	if (spawnpoint)
		host = new /mob/living/simple_animal/mouse(spawnpoint.loc)
	else
		src << "<span class='warning'>Unable to find any safe, unwelded vents to spawn mice at. The station must be quite a mess!  Trying again might work, if you think there's still a safe place. </span>"

	if(host)
		if(config.uneducated_mice)
			host.universal_understand = 0
		announce_ghost_joinleave(src, 0, "They are now a mouse.")
		host.ckey = src.ckey
		host << "<span class='info'>You are now a mouse. Interact with players, cause mischief, avoid cats, find food, and try to survive!</span>"


//Given an origin point to search around, attempts to find a safe vent as close as possible to that point
/proc/find_mouse_near_spawnpoint(var/turf/T)
	var/obj/machinery/atmospherics/unary/vent_pump/nearest_safe_vent = null
	var/nearest_dist = 999999
	for(var/obj/machinery/atmospherics/unary/vent_pump/v in SSmachines.machinery)
		if(!v.welded && v.z == T.z && !(is_turf_atmos_unsafe(get_turf(v))))
			var/distance = dist3D(v, T)
			if (distance < nearest_dist)
				nearest_safe_vent = v
				nearest_dist = distance

	return nearest_safe_vent

/proc/find_mouse_random_spawnpoint(var/ZLevel)
	//This function will attempt to find a good spawnpoint for mice, and prevent them from spawning in closed vent systems with no escape
	//It does this by bruteforce: Picks a random vent, tests if it has enough connections, if not, repeat
	//Continues either until a valid one is found (in which case we return it), or until we hit a limit on attempts..
	//If we hit the limit without finding a valid one, then the best one we found is selected

	var/list/found_vents = list()
	for(var/obj/machinery/atmospherics/unary/vent_pump/v in SSmachines.machinery)
		if(!v.welded && v.z == ZLevel)
			found_vents.Add(v)

	if (found_vents.len == 0)
		return null//Every vent on the map is welded? Sucks to be a mouse

	var/attempts = 0
	var/max_attempts = min(20, found_vents.len)
	var/target_connections = 30//Any vent with at least this many connections is good enough

	var/obj/machinery/atmospherics/unary/vent_pump/bestvent = null
	var/best_connections = 0
	while (attempts < max_attempts)
		attempts++
		var/obj/machinery/atmospherics/unary/vent_pump/testvent = pick(found_vents)

		if (!testvent.network)//this prevents runtime errors
			continue

		var/turf/T = get_turf(testvent)


		if (is_turf_atmos_unsafe(T))
			continue
		//----------------------




		//Now we test the vent connections, and ensure the vent we spawn at is connected enough to give the mouse free movement
		var/list/connections = list()
		for(var/obj/machinery/atmospherics/unary/vent_pump/temp_vent in testvent.network.normal_members)
			if(temp_vent.welded)
				continue
			if(temp_vent == testvent)//Our testvent shouldn't count itself as a connection
				continue

			connections += temp_vent

		if(connections.len > best_connections)
			best_connections = connections.len
			bestvent = testvent

		if (connections.len >= target_connections)
			return testvent
			//If we've found one that's good enough, then we stop looking


	//IF we get here, then we hit the limit without finding a valid one.
	//This would probably only be likely to happen if the station is full of holes and pipes are broken everywhere
	if (bestvent == null)
		//If bestvent is null, then every vent we checked was either welded or unsafe to spawn at. The user will be given a message reflecting this.
		return null
	else
		return bestvent

/mob/observer/ghost/verb/view_manfiest()
	set name = "Show Crew Manifest"
	set category = "Ghost"
	show_manifest(src)

//This is called when a ghost is drag clicked to something.
/mob/observer/ghost/MouseDrop(atom/over)
	if(!usr || !over) return
	if(isghost(usr) && usr.client && isliving(over))
		var/mob/living/M = over
		// If they an admin, see if control can be resolved.
		if(usr.client.holder && usr.client.holder.cmd_ghost_drag(src,M))
			return
		// Otherwise, see if we can possess the target.
		if(usr == src && try_possession(M))
			return
	if(istype(over, /obj/machinery/drone_fabricator))
		if(try_drone_spawn(src, over))
			return

	return ..()

/mob/observer/ghost/proc/try_possession(var/mob/living/M)
	if(!config.ghosts_can_possess_animals)
		usr << "<span class='warning'>Ghosts are not permitted to possess animals.</span>"
		return 0
	if(!M.can_be_possessed_by(src))
		return 0
	return M.do_possession(src)

/mob/observer/ghost/pointed(atom/A as mob|obj|turf in view())
	if(!..())
		return 0
	usr.visible_message("<span class='deadsay'><b>[src]</b> points to [A]</span>")
	return 1

/mob/observer/ghost/proc/manifest(mob/user)
	var/is_manifest = 0
	if(!is_manifest)
		is_manifest = 1
		verbs += /mob/observer/ghost/proc/toggle_visibility

	if(src.invisibility != 0)
		user.visible_message( \
			"<span class='warning'>\The [user] drags ghost, [src], to our plane of reality!</span>", \
			"<span class='warning'>You drag [src] to our plane of reality!</span>" \
		)
		toggle_visibility(1)
	else
		user.visible_message ( \
			"<span class='warning'>\The [user] just tried to smash \his book into that ghost!  It's not very effective.</span>", \
			"<span class='warning'>You get the feeling that the ghost can't become any more visible.</span>" \
		)

/mob/observer/ghost/proc/toggle_icon(var/icon)
	if(!client)
		return

	var/iconRemoved = 0
	for(var/image/I in client.images)
		if(I.icon_state == icon)
			iconRemoved = 1
			qdel(I)

	if(!iconRemoved)
		var/image/J = image('icons/mob/mob.dmi', loc = src, icon_state = icon)
		client.images += J

/mob/observer/ghost/proc/toggle_visibility(var/forced = 0)
	set category = "Ghost"
	set name = "Toggle Visibility"
	set desc = "Allows you to turn (in)visible (almost) at will."

	var/toggled_invisible
	if(!forced && invisibility && world.time < toggled_invisible + 600)
		src << "You must gather strength before you can turn visible again..."
		return

	if(invisibility == 0)
		toggled_invisible = world.time
		visible_message("<span class='emote'>It fades from sight...</span>", "<span class='info'>You are now invisible.</span>")
	else
		src << "<span class='info'>You are now visible!</span>"

	invisibility = invisibility == INVISIBILITY_OBSERVER ? 0 : INVISIBILITY_OBSERVER
	// Give the ghost a cult icon which should be visible only to itself
	toggle_icon("cult")

/mob/observer/ghost/verb/toggle_anonsay()
	set category = "Ghost"
	set name = "Toggle Anonymous Chat"
	set desc = "Toggles showing your key in dead chat."

	src.anonsay = !src.anonsay
	if(anonsay)
		src << "<span class='info'>Your key won't be shown when you speak in dead chat.</span>"
	else
		src << "<span class='info'>Your key will be publicly visible again.</span>"

/mob/observer/ghost/canface()
	return 1

/mob/proc/can_admin_interact()
    return 0

/mob/observer/ghost/can_admin_interact()
	return check_rights(R_ADMIN, 0, src)

/mob/observer/ghost/verb/toggle_ghostsee()
	set name = "Toggle Ghost Vision"
	set desc = "Toggles your ability to see things only ghosts can see, like other ghosts"
	set category = "Ghost"
	ghostvision = !(ghostvision)
	updateghostsight()
	usr << "You [(ghostvision?"now":"no longer")] have ghost vision."

/mob/observer/ghost/verb/toggle_darkness()
	set name = "Toggle Darkness"
	set category = "Ghost"
	seedarkness = !(seedarkness)
	updateghostsight()

/mob/observer/ghost/proc/updateghostsight()
	if (!seedarkness)
		see_invisible = SEE_INVISIBLE_NOLIGHTING
	else
		see_invisible = ghostvision ? SEE_INVISIBLE_OBSERVER : SEE_INVISIBLE_LIVING
	updateghostimages()

/mob/observer/ghost/proc/updateghostimages()
	if (!client)
		return
	client.images -= ghost_sightless_images
	client.images -= ghost_darkness_images
	if(!seedarkness)
		client.images |= ghost_sightless_images
		if(ghostvision)
			client.images |= ghost_darkness_images
	else if(seedarkness && !ghostvision)
		client.images |= ghost_sightless_images
	client.images -= ghost_image //remove ourself

/mob/observer/ghost/MayRespawn(var/feedback = 0, var/respawn_type = 0)
	if(!client)
		return 0
	if(config.antag_hud_restricted && has_enabled_antagHUD == 1)
		if(feedback)
			src << "<span class='warning'>antagHUD restrictions prevent you from respawning.</span>"
		return 0

	var/timedifference = world.time- get_death_time(respawn_type)
	var/respawn_time = 0
	if (respawn_type == CREW)
		respawn_time = config.respawn_delay MINUTES

		//Here we factor in bonuses added from cryosleep and similar things
		timedifference += get_respawn_bonus()
	else if (respawn_type == ANIMAL)
		respawn_time = ANIMAL_SPAWN_DELAY
	else if (respawn_type == MINISYNTH)
		respawn_time = DRONE_SPAWN_DELAY

	if(respawn_time &&  timedifference > respawn_time)
		return TRUE
	else
		if(feedback)
			var/timedifference_text = time2text(respawn_time  - timedifference,"mm:ss")
			src << "<span class='warning'>You must have been dead for [respawn_time / 600] minute\s to respawn. You have [timedifference_text] left.</span>"
		return 0

	return 1

/atom/proc/extra_ghost_link()
	return

/mob/extra_ghost_link(var/atom/ghost)
	if(client && eyeobj)
		return "|<a href='byond://?src=\ref[ghost];track=\ref[eyeobj]'>eye</a>"

/mob/observer/ghost/extra_ghost_link(var/atom/ghost)
	if(mind && mind.current)
		return "|<a href='byond://?src=\ref[ghost];track=\ref[mind.current]'>body</a>"

/proc/ghost_follow_link(var/atom/target, var/atom/ghost)
	if((!target) || (!ghost)) return
	. = "<a href='byond://?src=\ref[ghost];track=\ref[target]'>follow</a>"
	. += target.extra_ghost_link(ghost)


/mob/observer/proc/initialise_postkey()
	//This function should be run after a ghost has been created and had a ckey assigned
	//Death times are initialised if they were unset
	//get/set death_time functions are in mob_helpers.dm
	//These initialised times are designed to allow a player to immediately be a mouse or drone if they joined as observer from lobby
	if (!get_death_time(ANIMAL))
		set_death_time(ANIMAL, world.time - ANIMAL_SPAWN_DELAY)//allow instant mouse spawning
	if (!get_death_time(MINISYNTH))
		set_death_time(MINISYNTH, world.time - DRONE_SPAWN_DELAY) //allow instant drone spawning
	if (!get_death_time(CREW))
		set_death_time(CREW, world.time)


//Just a wrapper for abandon mob below, for ease of access.
/mob/observer/ghost/verb/respawn()
	set name = "Respawn as character"
	set category = "Ghost"
	abandon_mob()

/mob/verb/abandon_mob()
	set name = "Respawn"
	set category = "OOC"

	if (!( config.abandon_allowed ))
		usr << "<span class='notice'>Respawn is disabled.</span>"
		return

	if (istype(src, /mob/new_player))
		usr << "<span class='notice'><B>You are already at the lobby!</B></span>"
		return

	if (stat != DEAD)
		usr << "<span class='notice'><B>You must be dead to use this!</B></span>"
		return
	else if(!MayRespawn(1, CREW))
		if(!check_rights(0, 0) || alert("Normal players must wait at least [config.respawn_delay] minutes to respawn! Would you like to bypass it?","Warning", "No", "Ok") != "Ok")
			return

	//Wipe any bonuses gained in the previous (after)life
	clear_respawn_bonus()


	usr << "You can respawn now, enjoy your new life!"

	log_game("[usr.name]/[usr.key] used abandon mob.")

	usr << "<span class='notice'><B>If your character died, make sure to play a different character!</B></span>"

	if(!client)
		log_game("[usr.key] AM failed due to disconnect.")
		return
	client.screen.Cut()
	if(!client)
		log_game("[usr.key] AM failed due to disconnect.")
		return

	announce_ghost_joinleave(client, 0)

	var/mob/new_player/M = new /mob/new_player()
	if(!client)
		log_game("[usr.key] AM failed due to disconnect.")
		qdel(M)
		return

	M.key = key
	if(M.mind)
		M.mind.reset()
	return