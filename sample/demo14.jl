#Demo 5: Heat map
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

#Example using ColorSchemes
#(run `using Colorschemes` before running demo to test)
if @isdefined(ColorSchemes)
cs = ColorSchemes.leonardo
cmap = InspectDR.ColorMap(get(cs, range(0, stop=1, length=100)))
end


#Input data
#-------------------------------------------------------------------------------
x = collect(1.0:1.0:11.0)
y = collect(1.0:1.0:5.0)
z = float((1:10) * reshape(1:4, 1, :))
lz = log10.(z)
#normalize:
z = z ./ maximum(z)
lz = lz ./ maximum(lz)


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot(title="Heat Maps")
mplot.layout[:ncolumns] = 1

plot = add(mplot, InspectDR.Plot2D(:lin, [:lin, :lin],
		title="Heatmaps (upper: linear, lower: log)", xlabel="x", ylabels=["y", "y"])
	)
	strip_linz, strip_logz = plot.strips

	#Define extents & scales:
#	strip_logz.grid = InspectDR.GridRect(vmajor=true, hmajor=true, hminor=true)
	wfrm = addheatmap(plot, x, y, z, strip=1)
	wfrm = addheatmap(plot, x, y, lz, strip=2)

gplot = display(InspectDR.GtkDisplay(), mplot)

:DONE
