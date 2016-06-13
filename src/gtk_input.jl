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

function userinput_setstate_normal(pwidget::PlotWidget)
	pwidget.state = ISNormal()
end
userinput_donothing(pwidget::PlotWidget) = nothing


#==Wrapper functions
===============================================================================#
function raiseevent_plothover(pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	ext = getextents_xfrm(pwidget.src)
	xf = Transform2D(ext, pwidget.graphbb)
	pt = ptmap_rev(xf, Point2D(event.x, event.y))
	raiseevent(pwidget.eh_plothover, pwidget, DReal(pt.x), DReal(pt.y))
	nothing
end


#==Default event handlers
===============================================================================#
handleevent_mousepress(::InputState, pwidget::PlotWidget, event::Gtk.GdkEventButton) =
	nothing
handleevent_mouserelease(::InputState, pwidget::PlotWidget, event::Gtk.GdkEventButton) =
	nothing
function handleevent_mousemove(::InputState, pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	raiseevent_plothover(pwidget, event)
	nothing
end

#Event handler for plot widget keypress
#-------------------------------------------------------------------------------
function handleevent_keypress(::InputState, pwidget::PlotWidget, event::Gtk.GdkEventKey)
#event.event_type: GDK_KEY_PRESS/GDK_KEY_RELEASE
#@show event.event_type, event.state, event.keyval, event.length, event.string, event.hardware_keycode, event.group, event.flags
	global keybindings

	#Find bound functions & execute:
	if modifiers_pressed(event.state, 0)
		fn = get(keybindings.nomod, event.keyval, userinput_donothing)
		fn(pwidget)
	elseif modifiers_pressed(event.state, MODIFIER_SHIFT)
		fn = get(keybindings.shiftmod, event.keyval, userinput_donothing)
		fn(pwidget)
	elseif modifiers_pressed(event.state, MODIFIER_CTRL)
		fn = get(keybindings.ctrlmod, event.keyval, userinput_donothing)
		fn(pwidget)
	elseif modifiers_pressed(event.state, MODIFIER_ALT)
		fn = get(keybindings.altmod, event.keyval, userinput_donothing)
		fn(pwidget)
	end
#	@show event.keyval
end

function handleevent_mousescroll(::InputState, pwidget::PlotWidget, event::Gtk.GdkEventScroll)
	if modifiers_pressed(event.state, 0)
		if GdkScrollDirection.GDK_SCROLL_UP == event.direction
			pan_up(pwidget)
		elseif GdkScrollDirection.GDK_SCROLL_DOWN == event.direction
			pan_down(pwidget)
		end
	elseif modifiers_pressed(event.state, MODIFIER_SHIFT)
		if GdkScrollDirection.GDK_SCROLL_UP == event.direction
			pan_left(pwidget)
		elseif GdkScrollDirection.GDK_SCROLL_DOWN == event.direction
			pan_right(pwidget)
		end
	elseif modifiers_pressed(event.state, MODIFIER_CTRL)
		if GdkScrollDirection.GDK_SCROLL_UP == event.direction
			zoom_in(pwidget, event.x, event.y)
		elseif GdkScrollDirection.GDK_SCROLL_DOWN == event.direction
			zoom_out(pwidget, event.x, event.y)
		end
	end
end
function handleevent_scalechanged(::InputState, pwidget::PlotWidget)
	if !scalectrl_enabled(pwidget); return; end #Should not really happen
	scalectrl_apply(pwidget)
end


#==State: Normal input state
===============================================================================#
function handleevent_mousepress(::ISNormal, pwidget::PlotWidget, event::Gtk.GdkEventButton)
#	@show event.state, event.button, event.event_type
	if 3==event.button
		boxzoom_setstart(pwidget, event.x, event.y)
		pwidget.state = ISSelectingArea()
	elseif 1==event.button
		if modifiers_pressed(event.state, MODIFIER_SHIFT)
			mousepan_setstart(pwidget, event.x, event.y)
			pwidget.state = ISPanningData()
		end
	end

	focus(pwidget.widget) #In case not in focus
end


#==State: Selecting plot area
===============================================================================#
function handleevent_keypress(::ISSelectingArea, pwidget::PlotWidget, event::Gtk.GdkEventKey)
	if GdkKeySyms.Escape == event.keyval
		boxzoom_cancel(pwidget)
		pwidget.state = ISNormal()
	end
end
function handleevent_mouserelease(::ISSelectingArea, pwidget::PlotWidget, event::Gtk.GdkEventButton)
	if 3==event.button
		boxzoom_complete(pwidget, event.x, event.y)
		pwidget.state = ISNormal()
	end
end
function handleevent_mousemove(::ISSelectingArea, pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	raiseevent_plothover(pwidget, event)
	boxzoom_setend(pwidget, event.x, event.y)
end


#==State: Mouse pan
===============================================================================#
function handleevent_keypress(::ISPanningData, pwidget::PlotWidget, event::Gtk.GdkEventKey)
	if GdkKeySyms.Escape == event.keyval
		mousepan_cancel(pwidget)
		pwidget.state = ISNormal()
	end
end
function handleevent_mouserelease(::ISPanningData, pwidget::PlotWidget, event::Gtk.GdkEventButton)
	if 1==event.button
		mousepan_complete(pwidget, event.x, event.y)
		pwidget.state = ISNormal()
	end
end
function handleevent_mousemove(::ISPanningData, pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	raiseevent_plothover(pwidget, event)
	mousepan_move(pwidget, event.x, event.y)
end


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
