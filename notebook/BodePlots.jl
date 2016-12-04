module BodePlots

using InspectDR
using Colors

#Colour constants
#-------------------------------------------------------------------------------
const black = RGB24(0, 0, 0); const white = RGB24(1, 1, 1)
const red = RGB24(1, 0, 0); const green = RGB24(0, 1, 0); const blue = RGB24(0, 0, 1)

#Convenience aliases
#-------------------------------------------------------------------------------
mag(x) = abs(x); phase(x) = rad2deg(angle(x))
const j = im


#==Math: 2nd order transfer functions
===============================================================================#

function roots(a,b,c) #Solves: ax² + bx + c = 0
	r = sqrt(b*b-4*a*c)
	result = (-b .+ [r, -r]) / (2a)
	return (result[1], result[2])
end

#2nd order transfer function:
xf_o2(f, G, f_z, f_p1, f_p2) = #(f_z, f_p1, f_p2: in Hz)
	G*(1+j*(f./f_z))./( (1+j*(f./f_p1)).*(1+j*(f./f_p2)) )

#Compute unity gain frequency
function f_0(f, G, f_z, f_p1, f_p2)
	invsq(x) = (result = 1/x; return result*result)
	_z² = invsq(f_z); G² = G*G
	_p1² = invsq(f_p1); _p2² = invsq(f_p2)
	r = roots(_p1²*_p2², _p1²+_p2²-G²*_z², 1-G²)
	posroot = max(r...) #Select positive root
	return posroot < 0? NaN: sqrt(posroot)
end

#Compute 3dB frequency
f_3dB(f, G, f_z, f_p1, f_p2) =
	f_0(f, sqrt(2), f_z, f_p1, f_p2)

#==Main functions
===============================================================================#

#Create new Bode plot:
#-------------------------------------------------------------------------------
function new()
	const w = 500; const h = w/1.6 #Select plot width/height

	mplot = InspectDR.Multiplot(title="Bode Plot")
	mplot.ncolumns = 1
	#Bode plot looks better with wider aspect ratio:
	mplot.wplot = w; mplot.hplot = h/2

	plot_mag = add(mplot, InspectDR.Plot2D)
		plot_mag.axes = InspectDR.axes(:log10, :dB20)
		a = plot_mag.annotation; lyt = plot_mag.layout
		a.title = ""; lyt.htitle = 8 #No subtitle/space
		a.xlabel = ""; lyt.haxlabel = 8 #No axis label/space
		a.ylabel = "Magnitude (dB)"

	plot_phase = add(mplot, InspectDR.Plot2D)
		plot_phase.axes = InspectDR.axes(:log10, :lin)
		a = plot_phase.annotation; lyt = plot_phase.layout
		a.title = ""; lyt.htitle = 8 #subtitle/space
		a.xlabel = "Frequency (Hz)"; a.ylabel = "Phase (°)"

	for splot in [plot_mag, plot_phase]
		splot.layout.grid = grid(vmajor=true, vminor=true, hmajor=false)
	end
	
	return mplot
end

#Modify previously-generated Bode plot (base algorithm):
#-------------------------------------------------------------------------------
function update(mplot::InspectDR.Multiplot, f::Vector, y::Vector)
	const ldata = line(color=blue, width=3, style=:solid)

	plot_mag = mplot.subplots[1]
		plot_mag.data = [] #Clear old data
		plot_mag.ext_full = InspectDR.PExtents2D() #Reset full extents
		wfrm = add(plot_mag, f, mag(y))
		wfrm.line = ldata
		plot_mag.ext = InspectDR.PExtents2D(NaN, NaN, -10, 25)

	plot_phase = mplot.subplots[2]
		plot_phase.data = [] #Clear old data
		plot_phase.ext_full = InspectDR.PExtents2D() #Reset full extents
		wfrm = add(plot_phase, f, phase(y))
		wfrm.line = ldata
		plot_phase.ext = InspectDR.PExtents2D(NaN, NaN, -180, 0)

	return mplot
end

#Update annotation on Bode plot (enabled=false to clear annotation):
#-------------------------------------------------------------------------------
function update_annotation(mplot::InspectDR.Multiplot, f0, fBW, phase0, enabled=true)
	const lmarker = line(style=:dash, width=2.5)
	const lmarker_light = line(style=:dash, width=2.5, color=RGB24(.4,.4,.4))

	plot_mag = mplot.subplots[1]
		plot_mag.markers = [] #Clear old markers
		plot_mag.atext = [] #Clear old annotation
	plot_phase = mplot.subplots[2]
		plot_phase.markers = [] #Clear old markers
		plot_phase.atext = [] #Clear old annotation

	if !enabled; return mplot end

	#Add specialized annotation
	afont = InspectDR.Font(12) #Font for annotation

	#Add vertical markers to both plots:
	for splot in [plot_mag, plot_phase]
		isfinite(f0)? add(splot, vmarker(f0, lmarker)): nothing
		isfinite(fBW)? add(splot, vmarker(fBW, lmarker)): nothing
	end

	#Add annotation to Magnitude plot:
	add(plot_mag, atext("0dB", y=1, xoffset=0.5, yoffset=2/100, font=afont, align=:bc))
	add(plot_mag, hmarker(1, lmarker_light))

	if isfinite(fBW)
		fstr = "f3dB=" * @sprintf("%.1f MHz", fBW/1e6)
		add(plot_mag, atext(fstr, x=fBW, xoffset=-1/100, yoffset=.5, font=afont, angle=-90, align=:bc))
	end

	#Hack if f0>0: TODO: Fix bug where annotating @ 0 on log plot causes glitch. 
	if isfinite(f0) && f0 > 0
		fstr = "f0=" * @sprintf("%.1f MHz", f0/1e6)
		add(plot_mag, atext(fstr, x=f0, xoffset=-1/100, yoffset=.5, font=afont, angle=-90, align=:bc))
	end

	#Add annotation to Phase plot:
	if isfinite(phase0)
		pmargin = 180+phase0
		fstr = "PM=" * @sprintf("%.1f°", pmargin)
		add(plot_phase, atext(fstr, y=(phase0-180)/2, xoffset=0.5, font=afont, align=:cc))
		add(plot_phase, hmarker(phase0, lmarker))
	end

	return mplot
end

#Modify previously-generated Bode plot:
#-------------------------------------------------------------------------------
#(fmin, fmax, f_p1: in Hz)
function update(mplot::InspectDR.Multiplot, fmin, fmax, GdB, f_z, f_p1, f_p2, annot=true)
	const npts = 100
	const G = 10.0^(GdB/20)

	f = logspace(log10(fmin), log10(fmax), npts)
	y = xf_o2(f, G, f_z, f_p1, f_p2)
	update(mplot, f, y)

	f0 = f_0(f, G, f_z, f_p1, f_p2) #Unity gain frequency
	fBW = f_3dB(f, G, f_z, f_p1, f_p2)
	phase0 = phase(xf_o2(f0, G, f_z, f_p1, f_p2)) #Unity gain phase
	update_annotation(mplot, f0, fBW, phase0, annot)

	return mplot
end

#==Un-exported interface
===============================================================================
	new()
	update(::InspectDR.Multiplot, fmin, fmax, GdB, f_z, f_p1, f_p2, annot=true)
=#

end #module
