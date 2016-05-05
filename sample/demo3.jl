#Demo 1: Simple sine wave plot
#-------------------------------------------------------------------------------
using InspectDR
using Colors


#==Input
===============================================================================#
#Constants
#-------------------------------------------------------------------------------
black = RGB24(0, 0, 0)
white = RGB24(1, 1, 1)
red = RGB24(1, 0, 0)
green = RGB24(0, 1, 0)
blue = RGB24(0, 0, 1)

#Input data
#-------------------------------------------------------------------------------
npts = 200
ncycles = 4
Δ = ncycles/(npts-1)
t = collect(0:Δ:ncycles)
y = sin(2pi*t)


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot()
mplot.ncolumns = 2
xlabel = "Time (s)"
ylabel = "Signal Voltage (V)"

#First plot
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "sin(2πt)"
	a.xlabel = xlabel
	a.ylabel = ylabel
wfrm = add(plot, t, sin(2pi*t))
	wfrm.line = line(color=blue, width=1)

#Second plot
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "y(t) = (t-2)³"
	a.xlabel = xlabel
	a.ylabel = ylabel
wfrm = add(plot, t, (t-2).^3)
	wfrm.line = line(color=green, width=2)

#Third plot
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "-sin(2πt)"
	a.xlabel = xlabel
	a.ylabel = ylabel
wfrm = add(plot, t, -sin(2pi*t))
	wfrm.line = line(color=red, width=5)

#Display
#-------------------------------------------------------------------------------
gplot = display(InspectDR.GtkDisplay(), mplot)

:DONE
