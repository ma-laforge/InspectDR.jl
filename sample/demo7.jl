#Demo 7: Bode Plots
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
j = im

#Input data
#-------------------------------------------------------------------------------
fmax = 10e9
fstep = 5e6
f = collect(0:fstep:fmax)
fmin_disp = 10e6
G = 20.0
f_p1 = 50e6
f_p2 = .9e9
f_z = Inf #.8e9
f1 = .8e9


#==Helper functions
===============================================================================#
phase(x) = rad2deg(angle(x))
function roots(a,b,c)
	r = sqrt(b*b-4*a*c)
	result = (-b .+ [r, -r]) / (2a)
	return (result[1], result[2])
end
xf_o2(f, G, f_z, f_p1, f_p2) = #2nd order transfer function
	G*(1+j*(f./f_z))./( (1+j*(f./f_p1)).*(1+j*(f./f_p2)) )
function f_unitygain_f(f, G, f_z, f_p1, f_p2) #Compute unity gain frequency
	invsq(x) = (result = 1/x; return result*result)
	_z² = invsq(f_z); G² = G*G
	_p1² = invsq(f_p1); _p2² = invsq(f_p2)
	r = roots(_p1²*_p2², _p1²+_p2²-G²*_z², 1-G²) 
	return sqrt(max(r...)) #Select sqrt(positive root)
end
f_3dB(f, G, f_z, f_p1, f_p2) = #Compute 3dB frequency
	f_unitygain_f(f, sqrt(2), f_z, f_p1, f_p2)


#==Calculations
===============================================================================#
X = xf_o2(f, G, f_z, f_p1, f_p2)
f0 = f_unitygain_f(f, G, f_z, f_p1, f_p2)
fBW = f_3dB(f, G, f_z, f_p1, f_p2)
phase0 = phase(xf_o2(f0, G, f_z, f_p1, f_p2))
pmargin = 180+phase0
@show pmargin


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot(title="Bode Plot")
mplot.hplot*=.6 #Bode plot looks better with wider aspect ratio
mplot.ncolumns = 1

splot = plot_mag = add(mplot, InspectDR.Plot2D)
	splot.axes = InspectDR.axes(:log10, :dB20)
	splot.ext_full = InspectDR.PExtents2D(xmin=fmin_disp, ymin=-10)
	wfrm = add(splot, f, X)
		wfrm.line = line(color=blue, width=3)
	a = splot.annotation
#		a.title = ""
		a.xlabel = "Frequency (Hz)"; a.ylabel = "Magnitude (dB)"
	splot.layout.htitle = 8

splot = plot_phase = add(mplot, InspectDR.Plot2D)
	splot.axes = InspectDR.axes(:log10, :lin)
	splot.ext_full = InspectDR.PExtents2D(xmin=fmin_disp, ymin=-180)
	wfrm = add(splot, f, phase(X))
		wfrm.line = line(color=blue, width=3)
	a = splot.annotation
#		a.title = ""
		a.xlabel = "Frequency (Hz)"; a.ylabel = "Phase (°)"
	splot.layout.htitle = 8

#Add specialized annotation
#-------------------------------------------------------------------------------
afont = InspectDR.Font(12) #Font for annotation
markerline = line(style=:dash, width=2.5)
markerline_light = line(style=:dash, width=2.5, color=RGB24(.4,.4,.4))

#Add vertical markers to both plots:
for splot in [plot_mag, plot_phase]
	splot.layout.grid = grid(vmajor=true, vminor=true, hmajor=false)
	add(splot, vmarker(f0, markerline))
	add(splot, vmarker(fBW, markerline))
end

#Add annotation to Magnitude plot:
add(plot_mag, atext("0dB", y=1, xoffset=0.5, yoffset=2/100, font=afont, align=:bc))
add(plot_mag, hmarker(1, markerline_light))

fstr = "f3dB=" * @sprintf("%.1f MHz", fBW/1e6)
add(plot_mag, atext(fstr, x=fBW, xoffset=-1/100, yoffset=.5, font=afont, angle=-90, align=:bc))

fstr = "f0=" * @sprintf("%.1f MHz", f0/1e6)
add(plot_mag, atext(fstr, x=f0, xoffset=-1/100, yoffset=.5, font=afont, angle=-90, align=:bc))

#Add annotation to Phase plot:
fstr = "PM=" * @sprintf("%.1f°", pmargin)
add(plot_phase, atext(fstr, y=(phase0-180)/2, xoffset=0.5, font=afont, align=:cc))
add(plot_phase, hmarker(phase0, markerline))


#==Render plot
===============================================================================#
gplot = display(InspectDR.GtkDisplay(), mplot)

InspectDR.write_png("export_bode.png", mplot)
#InspectDR.write_svg("export_bode.svg", mplot)
#InspectDR.write_eps("export_bode.eps", mplot)
#InspectDR.write_pdf("export_bode.pdf", mplot)

:DONE
