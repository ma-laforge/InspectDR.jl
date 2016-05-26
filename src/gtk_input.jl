#InspectDR: Event handlers for user input of Gtk layer
#-------------------------------------------------------------------------------

import Gtk: GConstants.GdkModifierType, Gtk.GConstants.GdkScrollDirection


#==Constants
===============================================================================#
const MODIFIER_ALT = GdkModifierType.GDK_MOD1_MASK #Is this bad? How do I query?
const MODIFIER_CTRL = GdkModifierType.GDK_CONTROL_MASK
const MODIFIER_SHIFT = GdkModifierType.GDK_SHIFT_MASK

#Other modifiers are ignored... ex: numlock (Mod2)
const MODIFIERS_SUPPORTED = MODIFIER_ALT|MODIFIER_CTRL|MODIFIER_SHIFT

#Symbols not currently supported by Gtk package:
const GdkKeySyms_Plus = 0xffab
const GdkKeySyms_Minus = 0xffad


#==Types
===============================================================================#
typealias KeyMap Dict{Int, Function}

#User input states
immutable ISNormal <: InputState; end
immutable ISSelectingArea <: InputState; end
immutable ISPanningData <: InputState; end #Typically with mouse

type KeyBindings
	nomod::KeyMap
	shiftmod::KeyMap
	ctrlmod::KeyMap
	altmod::KeyMap
end
KeyBindings() = KeyBindings(KeyMap(), KeyMap(), KeyMap(), KeyMap())


#==Module-level definitions
===============================================================================#
const keybindings = KeyBindings()


#==Helper functions
===============================================================================#
modifiers_pressed(eventstate, modmask) = (modmask == (MODIFIERS_SUPPORTED & eventstate))

function userinput_setstate_normal(gplot::GtkPlot)
	gplot.state = ISNormal()
end
userinput_donothing(gplot::GtkPlot) = nothing


#==Default event handlers
===============================================================================#
handleevent_mousepress(::InputState, gplot::GtkPlot, event::Gtk.GdkEventButton) =
	nothing
handleevent_mouserelease(::InputState, gplot::GtkPlot, event::Gtk.GdkEventButton) =
	nothing
handleevent_mousemove(::InputState, gplot::GtkPlot, event::Gtk.GdkEventMotion) =
	nothing

#Event handler for plot widget keypress
#-------------------------------------------------------------------------------
function handleevent_keypress(::InputState, gplot::GtkPlot, event::Gtk.GdkEventKey)
#event.event_type: GDK_KEY_PRESS/GDK_KEY_RELEASE
#@show event.event_type, event.state, event.keyval, event.length, event.string, event.hardware_keycode, event.group, event.flags
	global keybindings

	#Find bound functions & execute:
	if modifiers_pressed(event.state, 0)
		fn = get(keybindings.nomod, event.keyval, userinput_donothing)
		fn(gplot)
	elseif modifiers_pressed(event.state, MODIFIER_SHIFT)
		fn = get(keybindings.shiftmod, event.keyval, userinput_donothing)
		fn(gplot)
	elseif modifiers_pressed(event.state, MODIFIER_CTRL)
		fn = get(keybindings.ctrlmod, event.keyval, userinput_donothing)
		fn(gplot)
	elseif modifiers_pressed(event.state, MODIFIER_ALT)
		fn = get(keybindings.altmod, event.keyval, userinput_donothing)
		fn(gplot)
	end
#	@show event.keyval
end

function handleevent_mousescroll(::InputState, gplot::GtkPlot, event::Gtk.GdkEventScroll)
	if modifiers_pressed(event.state, 0)
		if GdkScrollDirection.GDK_SCROLL_UP == event.direction
			pan_up(gplot)
		elseif GdkScrollDirection.GDK_SCROLL_DOWN == event.direction
			pan_down(gplot)
		end
	elseif modifiers_pressed(event.state, MODIFIER_SHIFT)
		if GdkScrollDirection.GDK_SCROLL_UP == event.direction
			pan_left(gplot)
		elseif GdkScrollDirection.GDK_SCROLL_DOWN == event.direction
			pan_right(gplot)
		end
	elseif modifiers_pressed(event.state, MODIFIER_CTRL)
		if GdkScrollDirection.GDK_SCROLL_UP == event.direction
			zoom_in(gplot, event.x, event.y)
		elseif GdkScrollDirection.GDK_SCROLL_DOWN == event.direction
			zoom_out(gplot, event.x, event.y)
		end
	end
end
function handleevent_scalechanged(::InputState, gplot::GtkPlot)
	if !scalectrl_enabled(gplot); return; end #Should not really happen
	scalectrl_apply(gplot)
end


#==State: Normal input state
===============================================================================#
function handleevent_mousepress(::ISNormal, gplot::GtkPlot, event::Gtk.GdkEventButton)
#	@show event.state, event.button, event.event_type
	if 3==event.button
		boxzoom_setstart(gplot, event.x, event.y)
		gplot.state = ISSelectingArea()
	elseif 1==event.button
		if modifiers_pressed(event.state, MODIFIER_SHIFT)
			mousepan_setstart(gplot, event.x, event.y)
			gplot.state = ISPanningData()
		end
	end

	focus(gplot.widget) #In case not in focus
end


#==State: Selecting plot area
===============================================================================#
function handleevent_keypress(::ISSelectingArea, gplot::GtkPlot, event::Gtk.GdkEventKey)
	if GdkKeySyms.Escape == event.keyval
		boxzoom_cancel(gplot)
		gplot.state = ISNormal()
	end
end
function handleevent_mouserelease(::ISSelectingArea, gplot::GtkPlot, event::Gtk.GdkEventButton)
	if 3==event.button
		boxzoom_complete(gplot, event.x, event.y)
		gplot.state = ISNormal()
	end
end
handleevent_mousemove(::ISSelectingArea, gplot::GtkPlot, event::Gtk.GdkEventMotion) =
	boxzoom_setend(gplot, event.x, event.y)


#==State: Mouse pan
===============================================================================#
function handleevent_keypress(::ISPanningData, gplot::GtkPlot, event::Gtk.GdkEventKey)
	if GdkKeySyms.Escape == event.keyval
		mousepan_cancel(gplot)
		gplot.state = ISNormal()
	end
end
function handleevent_mouserelease(::ISPanningData, gplot::GtkPlot, event::Gtk.GdkEventButton)
	if 1==event.button
		mousepan_complete(gplot, event.x, event.y)
		gplot.state = ISNormal()
	end
end
handleevent_mousemove(::ISPanningData, gplot::GtkPlot, event::Gtk.GdkEventMotion) =
	mousepan_move(gplot, event.x, event.y)


#==Key bindings
===============================================================================#
function keybindings_setdefaults(bnd::KeyBindings)
	bnd.nomod = KeyMap(
		GdkKeySyms.Escape => userinput_setstate_normal,
		'f' => zoom_full,
		GdkKeySyms.Up => pan_up,
		GdkKeySyms.Down => pan_down,
		GdkKeySyms.Left => pan_left,
		GdkKeySyms.Right => pan_right,
		GdkKeySyms_Plus => zoom_in,
		GdkKeySyms_Minus => zoom_out,
	)
	bnd.shiftmod = KeyMap(
	)
	bnd.ctrlmod = KeyMap(
	)
	bnd.altmod = KeyMap(
	)
end

#Last line
