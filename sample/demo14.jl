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
#(run `using ColorSchemes` before running demo to test)
if @isdefined(ColorSchemes)
cs = ColorSchemes.jet1
colorscale = InspectDR.ColorScale(get(cs, range(0, stop=1, length=100)))
end


#Input data
#-------------------------------------------------------------------------------
x = collect(0:1.0:10.0)
y = collect(0:1.0:4.0)
zi = float((1:10) * reshape(1:4, 1, :))
zmax = maximum(zi); zmin = minimum(zi)
z = (zi.+.25*zmax).*1e9
lz = (zi.-zmin.+1e-3)
lz = log10.(lz.*lz.*1e3)


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot(title="Heat Maps")
mplot.layout[:ncolumns] = 1

plot = add(mplot, InspectDR.Plot2D(:lin, [:lin, :lin],
		title="Heatmaps (upper: linear, lower: log)", xlabel="x", ylabels=["y", "y"])
	)
	plot.layout[:enable_colorscale] = true
	strip_linz, strip_logz = plot.strips

if @isdefined(ColorSchemes)
	strip_linz.colorscale = colorscale
	strip_logz.colorscale = colorscale
end

	#Define extents & scales:
#	strip_logz.grid = InspectDR.GridRect(vmajor=true, hmajor=true, hminor=true)
	wfrm = addheatmap(plot, x, y, z, strip=1)
	wfrm = addheatmap(plot, x, y, lz, strip=2)

gplot = display(InspectDR.GtkDisplay(), mplot)

:DONE
