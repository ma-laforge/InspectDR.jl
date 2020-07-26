#InspectDR: Event handling with Gtk
#-------------------------------------------------------------------------------

import Gtk: GConstants.GdkScrollDirection


#==Constants
===============================================================================#
#Symbols not currently supported by Gtk.GdkKeySyms:
const GdkKeySyms_Plus = Gtk.GConstants.GDK_KEY_KP_Add
const GdkKeySyms_Minus = Gtk.GConstants.GDK_KEY_KP_Subtract


#==Main types
===============================================================================#
struct ISNormal <: InputState; end #Default state


#==Helper functions
===============================================================================#
modifiers_pressed(eventstate, modmask) = (modmask == (MODIFIERS_SUPPORTED & eventstate))

#Returns 0 or strip index:
#TODO: refer to graphbblist only - instead of pwidget???
function hittest(pwidget::PlotWidget, x::Float64, y::Float64)
	maplist = pwidget.rplot.strips #WANTCONST
	for i = 1:length(maplist)
		if isinside(maplist[i].bb, x, y)
			return i
		end
	end
	return 0
end


#==Wrapper functions
===============================================================================#
raiseevent_plothover(pwidget::PlotWidget, event::Gtk.GdkEventMotion) =
	raiseevent(pwidget.eh_plothover, pwidget, event.x, event.y)


#==Low-level event handlers
===============================================================================#
function handleevent_plothover(pwidget::PlotWidget, event::Gtk.GdkEventMotion, istrip::Int)
	x, y = event.x, event.y

	if istrip > 0
		#TODO: do we want "read"able coords?
		pwidget.mouseover.pos = dev2axis(pwidget.rplot.strips[istrip], Point2D(x, y))
	else
		pwidget.mouseover.pos = nothing
	end

	raiseevent_plothover(pwidget, event) #Inform owner
	return
end

#Update pwidget.mouseover & raise event to owner
function handleevent_plothover(pwidget::PlotWidget, event::Gtk.GdkEventMotion)
	x, y = event.x, event.y
	istrip = hittest(pwidget, x, y)
	pwidget.mouseover.istrip = istrip
	handleevent_plothover(pwidget, event, istrip)
	return
end


#Last line
