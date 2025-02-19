/obj/item/clothing/accessory/holster
	name = "shoulder holster"
	desc = "A leather handgun holster mounted around the shoulder."
	icon_state = "holster"
	slot = "utility"
	price_tag = 100
	var/obj/item/holstered = null

/obj/item/clothing/accessory/holster/proc/holster(var/obj/item/I, var/mob/living/user)
	if(holstered && istype(user))
		user << SPAN_WARNING("There is already \a [holstered] holstered here!")
		return

	if (!(I.slot_flags & SLOT_HOLSTER))
		user << SPAN_WARNING("[I] won't fit in [src]!")
		return

	holstered = I
	user.drop_from_inventory(holstered)
	holstered.loc = src
	holstered.add_fingerprint(user)
	w_class = max(w_class, holstered.w_class)
	user.visible_message(SPAN_NOTICE("[user] holsters \the [holstered]."), SPAN_NOTICE("You holster \the [holstered]."))
	name = "occupied [initial(name)]"

/obj/item/clothing/accessory/holster/proc/clear_holster()
	holstered = null
	name = initial(name)

/obj/item/clothing/accessory/holster/proc/unholster(mob/user as mob)
	if(!holstered)
		return

	if(istype(user.get_active_hand(),/obj) && istype(user.get_inactive_hand(),/obj))
		user << SPAN_WARNING("You need an empty hand to draw \the [holstered]!")
	else
		if(user.a_intent == I_HURT)
			usr.visible_message(
				SPAN_DANGER("[user] draws \the [holstered], ready to shoot!"),
				SPAN_WARNING("You draw \the [holstered], ready to shoot!")
				)
		else
			user.visible_message(
				SPAN_NOTICE("[user] draws \the [holstered], pointing it at the ground."),
				SPAN_NOTICE("You draw \the [holstered], pointing it at the ground.")
				)
		user.put_in_hands(holstered)
		holstered.add_fingerprint(user)
		w_class = initial(w_class)
		clear_holster()

/obj/item/clothing/accessory/holster/attack_hand(mob/user as mob)
	if (has_suit)	//if we are part of a suit
		if (holstered)
			unholster(user)
		return

	..(user)

/obj/item/clothing/accessory/holster/attackby(obj/item/W as obj, mob/user as mob)
	holster(W, user)

/obj/item/clothing/accessory/holster/emp_act(severity)
	if (holstered)
		holstered.emp_act(severity)
	..()

/obj/item/clothing/accessory/holster/examine(mob/user)
	..(user)
	if (holstered)
		user << "A [holstered] is holstered here."
	else
		user << "It is empty."

/obj/item/clothing/accessory/holster/on_attached(obj/item/clothing/under/S, mob/user as mob)
	..()
	has_suit.verbs += /obj/item/clothing/accessory/holster/verb/holster_verb

/obj/item/clothing/accessory/holster/on_removed(mob/user as mob)
	has_suit.verbs -= /obj/item/clothing/accessory/holster/verb/holster_verb
	..()

//For the holster hotkey
/obj/item/clothing/accessory/holster/verb/holster_verb()
	set name = "Holster"
	set category = "Object"
	set src in usr
	if(!isliving(usr))
		return
	if(usr.stat)
		return

	//can't we just use src here?
	var/obj/item/clothing/accessory/holster/H = null
	if (istype(src, /obj/item/clothing/accessory/holster))
		H = src
	else if (istype(src, /obj/item/clothing/under))
		var/obj/item/clothing/under/S = src
		if (S.accessories.len)
			H = locate() in S.accessories

	if (!H)
		usr << SPAN_WARNING("Something is very wrong.")

	if(!H.holstered)
		var/obj/item/W = usr.get_active_hand()
		if(!istype(W, /obj/item))
			usr << SPAN_WARNING("You need your gun equiped to holster it.")
			return
		H.holster(W, usr)
	else
		H.unholster(usr)

/obj/item/clothing/accessory/holster/armpit
	name = "armpit holster"
	desc = "A leather handgun holster mounted around the armpit."
	icon_state = "holster"

/obj/item/clothing/accessory/holster/waist
	name = "waist holster"
	desc = "A leather handgun holster mounted around the waist."
	icon_state = "holster"
	overlay_state = "holster_low"

/obj/item/clothing/accessory/holster/hip
	name = "hip holster"
	desc = "A leather handgun holster mounted around the hip."
	icon_state = "holster_hip"

/obj/item/clothing/accessory/holster/leg
	name = "leg holster"
	desc = "A tacticool handgun holster. Worn on the upper leg."
	icon_state = "holster_leg"
	overlay_state = "holster_leg"
