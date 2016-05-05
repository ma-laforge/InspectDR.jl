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
plot = InspectDR.Plot2D()
style = :dashdot #solid/dashdot/...

wfrm = add(plot, x, y+1)
	wfrm.line = line(color=blue, width=1, style=style)
wfrm = add(plot, x, y-1)
	wfrm.line = line(color=red, width=5, style=style)
wfrm = add(plot, x_lres, -2+4*(x_lres./ncycles))
	wfrm.line = line(color=blue, width=3, style=:dash)
	wfrm.glyph = glyph(shape=:circle)
#shape=:circle, :square, :uarrow, darrow, :rarrow, :larrow

a = plot.annotation
a.title = "Sample Plot (λ)"
a.xlabel = "Time (s)"
a.ylabel = "Signal Voltage (V)"

gplot = display(InspectDR.GtkDisplay(), plot)

InspectDR.write_png("plotsave.png", plot)
InspectDR.write_svg("plotsave.svg", plot)
InspectDR.write_eps("plotsave.eps", plot)
InspectDR.write_pdf("plotsave.pdf", plot)

:DONE
