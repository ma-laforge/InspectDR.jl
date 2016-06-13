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
npts = 2000 #Relatively large dataset
ncycles = 4
Δ = ncycles/(npts-1)
x = collect(0:Δ:ncycles)
y = sin(2pi*x)

x[end] = x[1] #x-values are no longer ordered

#Lower resolution x-vector:
x_lres = collect(0:(ncycles/10):ncycles)


#==Generate plot
===============================================================================#
plot = InspectDR.Plot2D(title="Sample Plot (λ)")
plot.layout = InspectDR.Layout(fontname="monospace", fontscale=1.5)
plot.layout.grid = grid(vmajor=true, vminor=true, hmajor=true)
plot.layout.legend.enabled = true
plot.layout.legend.width = 150
plot.layout.showtimestamp = true

style = :dashdot #solid/dashdot/...
wfrm = add(plot, x, y+1, id="sin(2πt)+1")
	wfrm.line = line(color=blue, width=1, style=style)
wfrm = add(plot, x, y-1, id="sin(2πt)-1")
	wfrm.line = line(color=red, width=5, style=style)
wfrm = add(plot, x_lres, -2+4*(x_lres./ncycles), id="-2+4t/$ncycles")
	wfrm.line = line(color=blue, width=3, style=:dash)
	wfrm.glyph = glyph(shape=:*, size=10)
#= Supported shapes:
	:square, :diamond,
	:uarrow, :darrow, :larrow, :rarrow, #usually triangles
	:cross, :+, :diagcross, :x,
	:circle, :o, :star, :*,
=#

a = plot.annotation
a.xlabel = "Time (s)"
a.ylabel = "Signal Voltage (V)"

gplot = display(InspectDR.GtkDisplay(), plot)

InspectDR.write_png("export_plot.png", plot)
InspectDR.write_svg("export_plot.svg", plot)
InspectDR.write_eps("export_plot.eps", plot)
InspectDR.write_pdf("export_plot.pdf", plot)

:DONE
