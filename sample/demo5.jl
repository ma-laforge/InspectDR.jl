#Demo 5: Logy plots
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
x = collect(1.0:1.0:100.0)
b = 2.0 #Base
k = 0.2 #Exponential coefficient


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot(title="Log-Y Tests")
mplot.ncolumns = 1

plot_liny = InspectDR.Plot2D()
	plot_liny.axes = InspectDR.axes(:lin, :lin)
plot_logy = InspectDR.Plot2D()
	plot_logy.axes = InspectDR.axes(:lin, :log10)
	plot_logy.layout.grid = grid(vmajor=true, hmajor=true, hminor=true)

plotlist = [plot_liny, plot_logy]

for plot in plotlist
	wfrm = add(plot, x, b.^(k*x))
	wfrm.line = line(color=blue, width=3)

	add(mplot, plot)
	a = plot.annotation
	a.title = "y = $b^($(k)x)"
	a.xlabel = "x"
	a.ylabel = "y"
end

gplot = display(InspectDR.GtkDisplay(), mplot)

:DONE
