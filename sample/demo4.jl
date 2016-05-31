#Demo 4: Empty/undefined plots
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


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot(title="Empty/Undefined Plots")
mplot.ncolumns = 2
xlabel = "Time (s)"
ylabel = "Signal Voltage (V)"

#Subplot 1
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "xmax = ∞"
	a.xlabel = xlabel
	a.ylabel = ylabel
wfrm = add(plot, Float64[0, Inf], Float64[0, 1])

#Subplot 2
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "xmin = NaN"
	a.xlabel = xlabel
	a.ylabel = ylabel
wfrm = add(plot, Float64[NaN, 1], Float64[0, 1])

#Subplot 3
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "ymin = -∞"
	a.xlabel = xlabel
	a.ylabel = ylabel
wfrm = add(plot, Float64[0, 1], Float64[-Inf, 0])

#Subplot 4
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "ymax = NaN"
	a.xlabel = xlabel
	a.ylabel = ylabel
wfrm = add(plot, Float64[0, 1], Float64[1, NaN])

#Subplot 5
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "No Data"
	a.xlabel = xlabel
	a.ylabel = ylabel

#Subplot 6
#-------------------------------------------------------------------------------
plot = add(mplot, InspectDR.Plot2D)
a = plot.annotation
	a.title = "xmin = xmax"
	a.xlabel = xlabel
	a.ylabel = ylabel
wfrm = add(plot, Float64[2, 2], Float64[0, 1])

#Display
#-------------------------------------------------------------------------------
gplot = display(InspectDR.GtkDisplay(), mplot)

:DONE
