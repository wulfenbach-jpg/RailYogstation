/obj/machinery/space_heater
	anchored = 0
	density = 1
	icon = 'icons/obj/atmos.dmi'
	icon_state = "sheater0"
	name = "space heater"
	desc = "Made by Space Amish using traditional space techniques, this heater is guaranteed not to set the station on fire."
	var/obj/item/weapon/stock_parts/cell/cell
	var/on = 0
	var/open = 0
	var/set_temperature = 50		// in celcius, add T0C for kelvin
	var/heating_power = 40000


/obj/machinery/space_heater/New()
	..()
	cell = new(src)
	cell.charge = 1000
	cell.maxcharge = 1000
	update_icon()
	return

/obj/machinery/space_heater/update_icon()
	overlays.Cut()
	icon_state = "sheater[on]"
	if(open)
		overlays  += "sheater-open"
	return

/obj/machinery/space_heater/examine(mob/user)

	..()
	user << "The heater is [on ? "on" : "off"] and the hatch is [open ? "open" : "closed"]."
	if(open)
		user << "A power cell is [cell ? "installed" : "missing"]."
	else
		user << "The charge meter reads [cell ? round(cell.percent(),1) : 0]%."

/obj/machinery/space_heater/emp_act(severity)
	if(stat & (BROKEN|NOPOWER))
		..(severity)
		return
	if(cell)
		cell.emp_act(severity)
	..(severity)

/obj/machinery/space_heater/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/weapon/stock_parts/cell))
		if(open)
			if(cell)
				user << "There is already a power cell inside."
				return
			else
				// insert cell
				var/obj/item/weapon/stock_parts/cell/C = usr.get_active_hand()
				if(istype(C))
					user.drop_item()
					cell = C
					C.loc = src
					C.add_fingerprint(usr)

					user.visible_message("<span class='notice'>[user] inserts a power cell into [src].</span>", "<span class='notice'>You insert the power cell into [src].</span>")
		else
			user << "The hatch must be open to insert a power cell."
			return
	else if(istype(I, /obj/item/weapon/screwdriver))
		open = !open
		user.visible_message("<span class='notice'>[user] [open ? "opens" : "closes"] the hatch on \the [src].</span>", "<span class='notice'>You [open ? "open" : "close"] the hatch on \the [src].</span>")
		update_icon()
		if(!open && user.machine == src)
			user << browse(null, "window=spaceheater")
			user.unset_machine()
	else
		..()
	return

/obj/machinery/space_heater/attack_hand(mob/user as mob)
	src.add_fingerprint(user)
	if(open)

		var/dat
		dat = "Power cell: "
		if(cell)
			dat += "<A href='byond://?src=\ref[src];op=cellremove'>Installed</A><BR>"
		else
			dat += "<A href='byond://?src=\ref[src];op=cellinstall'>Removed</A><BR>"

		dat += "Power Level: [cell ? round(cell.percent(),1) : 0]%<BR><BR>"

		dat += "Set Temperature: "

		dat += "<A href='?src=\ref[src];op=temp;val=-5'>-</A>"

		dat += " [set_temperature]&deg;C "
		dat += "<A href='?src=\ref[src];op=temp;val=5'>+</A><BR>"

		user.set_machine(src)
		user << browse("<HEAD><TITLE>Space Heater Control Panel</TITLE></HEAD><TT>[dat]</TT>", "window=spaceheater")
		onclose(user, "spaceheater")




	else
		on = !on
		user.visible_message("<span class='notice'>[user] switches [on ? "on" : "off"] \the [src].</span>","<span class='notice'>You switch [on ? "on" : "off"] \the [src].</span>")
		update_icon()
	return


/obj/machinery/space_heater/Topic(href, href_list)
	if(..())
		return
	usr.set_machine(src)

	switch(href_list["op"])

		if("temp")
			var/value = text2num(href_list["val"])

			// limit to 20-90 degC
			set_temperature = dd_range(20, 90, set_temperature + value)

		if("cellremove")
			if(open && cell && !usr.get_active_hand())
				cell.updateicon()
				usr.put_in_hands(cell)
				cell.add_fingerprint(usr)
				cell = null
				usr.visible_message("<span class='notice'>[usr] removes the power cell from \the [src].</span>", "<span class='notice'>You remove the power cell from \the [src].</span>")


		if("cellinstall")
			if(open && !cell)
				var/obj/item/weapon/stock_parts/cell/C = usr.get_active_hand()
				if(istype(C))
					usr.drop_item()
					cell = C
					C.loc = src
					C.add_fingerprint(usr)

					usr.visible_message("<span class='notice'>[usr] inserts a power cell into \the [src].</span>", "<span class='notice'>You insert the power cell into \the [src].</span>")

	updateDialog()


/obj/machinery/space_heater/process()
	if(on)
		if(cell && cell.charge > 0)

			var/turf/simulated/L = loc
			if(istype(L))
				var/datum/gas_mixture/env = L.return_air()
				if(env.temperature < (set_temperature+T0C))

					var/transfer_moles = 0.25 * env.total_moles()

					var/datum/gas_mixture/removed = env.remove(transfer_moles)

					//world << "got [transfer_moles] moles at [removed.temperature]"

					if(removed)

						var/heat_capacity = removed.heat_capacity()
						//world << "heating ([heat_capacity])"
						if(heat_capacity == 0 || heat_capacity == null) // Added check to avoid divide by zero (oshi-) runtime errors
							heat_capacity = 1
						removed.temperature = min((removed.temperature*heat_capacity + heating_power)/heat_capacity, 1000) // Added min() check to try and avoid wacky superheating issues in low gas scenarios
						cell.use(heating_power/20000)

						//world << "now at [removed.temperature]"

					env.merge(removed)
					air_update_turf()

					//world << "turf now at [env.temperature]"


		else
			on = 0
			update_icon()



	return