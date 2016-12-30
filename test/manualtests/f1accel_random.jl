#Stress test for f1 acceleration
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
srand(33)
y = rand(100000)
x = collect(1:length(y))


#==Generate plot
===============================================================================#
plot = InspectDR.Plot2D(title="Random Data Stressor")
plot.xres = 30 #coarse resolution
#Δ = 1.323443/length(y)
#plot.ext_full = InspectDR.PExtents2D(Δ, x[end]-2*Δ, NaN, NaN)
plot.ext_full = InspectDR.PExtents2D(10, 2100, NaN, NaN)
#plot.layout.grid = grid(vmajor=true, vminor=true, hmajor=true)

style = :dashdot #solid/dashdot/...
wfrm = add(plot, x, y, id="rand")
#	wfrm.line = line(style=:none)
	wfrm.line = line(style=:solid, color=blue)
#	wfrm.glyph = glyph(shape=:o, size=10, color=blue)

a = plot.annotation
a.xlabel = "Time (s)"
a.ylabel = "Signal Voltage (V)"

gplot = display(InspectDR.GtkDisplay(), plot)

:Test_Complete
