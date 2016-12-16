
if !isdefined(:BodePlots)
include("BodePlots.jl")
end

module PhaseLock

import BodePlots

using InspectDR
import InspectDR: Plot2D
using NumericIO
using Colors

#Colour constants
#-------------------------------------------------------------------------------
const black = RGB24(0, 0, 0); const white = RGB24(1, 1, 1)
const red = RGB24(1, 0, 0); const green = RGB24(0, 1, 0); const blue = RGB24(0, 0, 1)

#Convenience aliases
#-------------------------------------------------------------------------------
mag(x) = abs(x); phase(x) = rad2deg(angle(x))
SI(x) = formatted(x, :SI, ndigits=3)
const j = im


#==Main types
===============================================================================#

#1st order transfer function:
type Xf1
	K::Float64
	ωz::Float64
	ωp::Float64
end
Xf1(;K=1, ωz=1, ωp=1) = Xf1(K, ωz, ωp)

#2nd order system (standard form):
type Sys2
	α::Float64
	ζ::Float64
	ωn::Float64
end
Sys2(;α=1, ζ=1, ωn=1) = Sys2(α, ζ, ωn)

function Sys2(G::Xf1)
	ωn = sqrt(G.K*G.ωp)
	ζ = 0.5*(G.ωp/ωn+ωn/G.ωz)
	α = ωn/(2*ζ*G.K)
	return Sys2(α=α, ζ=ζ, ωn=ωn)
end

#==Math: 2nd order transfer functions
===============================================================================#

#Open-loop transfer function, G(s) (including freq->phase integrator):
xf_ol(ω::Vector, G::Xf1) = (s=j*ω;
	return G.K*(1+s./G.ωz)./(1+s./G.ωp) ./ s)

#Compute unity gain frequency of G(s) (including freq->phase integrator):
function ω_0(G::Xf1)
	invsq(x) = (result = 1/x; return result*result)
	K² = G.K*G.K
	a = invsq(G.ωp)
	b = (1-K²*invsq(G.ωz))
	c = -K²
	r = BodePlots.roots(a,b,c) #Roots of ω²

	const thresh = deg2rad(1) #1 degree
	rvalid = Float64[NaN,NaN]
	for i in 1:2
		val = r[i]
		if abs(angle(val)) < thresh #Positive real root
			rvalid[i] = sqrt(abs(val))
		end
	end

	return min(rvalid...) #Select first crossing of |G|=1
end

function step_err(s::Sys2, t::Vector)
	const α = s.α
	const ωn = s.ωn
	const ζ = s.ζ
	csqrt(x) = sqrt(complex(x))
	ζroot = csqrt(ζ^2-1)
	herr(f) = (ζ*(2α-1)/ζroot+f*1)*exp(-ωn*t*(ζ+f*ζroot))

	if ζroot == 0 # ζ = 1
		return (1+(1-2α)*(ωn*t)).*exp(-ωn*t)
	else
		return (herr(1)-herr(-1)) / 2
	end
end

step_resp(s::Sys2, t::Vector) = 1-step_err(s, t)

#==Main functions
===============================================================================#
function newplot()
	const w = 500; const h = w/1.6 #Select plot width/height

	mplot = InspectDR.Multiplot(title="PLL Characteristics")
	mplot.ncolumns = 2
	#Bode plot looks better with wider aspect ratio:
	mplot.wplot = w; mplot.hplot = h/2

	plot_mag = add(mplot, InspectDR.Plot2D)
	plot_step = add(mplot, InspectDR.Plot2D)
	plot_phase = add(mplot, InspectDR.Plot2D)
	plot_stepnorm = add(mplot, InspectDR.Plot2D)

	#Bode plot:
	BodePlots.init(plot_mag, plot_phase)

	#Add title to bode plot:
	a = plot_mag.annotation; lyt = plot_mag.layout
		lyt.htitle = plot_step.layout.htitle #Restore space for subtitle
		a.title = "Open-Loop Characteristics"

	#Step-response plot:
	a = plot_step.annotation; lyt = plot_step.layout
		a.title = "Step Response"
		a.xlabel = "Time (s)"
		a.ylabel = "Amplitude"
#		plot_step.layout.grid = grid(vmajor=true, vminor=true, hmajor=false)

	a = plot_stepnorm.annotation; lyt = plot_stepnorm.layout
		a.title = ""; lyt.htitle = 8 #subtitle/space
		a.xlabel = "ωn*t (rad)"
		a.ylabel = "Amplitude"
	
	return mplot
end

#Modify previously-generated Bode plot (base algorithm):
#-------------------------------------------------------------------------------
function update_step(plot::InspectDR.Plot2D, t::Vector, y::Vector)
	const ldata = line(color=blue, width=3, style=:solid)

	plot.data = [] #Clear old data
	plot.ext_full = InspectDR.PExtents2D() #Reset full extents
	wfrm = add(plot, t, mag(y))
	wfrm.line = ldata
	plot.ext = InspectDR.PExtents2D(NaN, NaN, 0, 1.6)
	return plot
end

#Update annotation on Bode plot (enabled=false to clear annotation):
#-------------------------------------------------------------------------------
function update_bodeannot(plot_mag::Plot2D, plot_phase::Plot2D, G::Xf1, ωn)
	const lmarker = line(style=:dash, width=2.5)
	const lmarker_light = line(style=:solid, width=2.5, color=RGB24(.4,.4,.4))
	const fp = G.ωp/(2pi)
	const fz = G.ωz/(2pi)
	const fn = ωn/(2pi)
	const ω0 = ω_0(G)
	const f0 = ω0/(2pi)
	const phase0 = phase(xf_ol([ω0], G)[1]) #Unity gain phase

	#Add specialized annotation
	afont = InspectDR.Font(12) #Font for annotation

	#Add annotation to Magnitude plot:
#	add(plot_mag, atext("0dB", y=1, xoffset=0.5, yoffset=2/100, font=afont, align=:bc))
	add(plot_mag, hmarker(1, lmarker_light))

	polelist = [("fp", fp), ("fz", fz), ("fn", fn), ("f0", f0)]
	#Hack if f0>0: TODO: Fix bug where annotating text @ 0 on log plot causes glitch. 
	for (id, f) in polelist
		if isfinite(f) && f > 0
			fstr = id * "=" * SI(f) * "Hz"
			add(plot_mag, atext(fstr, x=f, xoffset=-1/100, yoffset=.5, font=afont, angle=-90, align=:bc))

			#Add vertical markers to both plots:
			add(plot_mag, vmarker(f, lmarker))
			add(plot_phase, vmarker(f, lmarker))
		end
	end

	#Add annotation to Phase plot:
	if isfinite(phase0)
		pmargin = 180+phase0
		fstr = "PM=" * @sprintf("%.1f°", pmargin)
		add(plot_phase, atext(fstr, y=(phase0-180)/2, xoffset=0.5, font=afont, align=:cc))
		add(plot_phase, hmarker(phase0, lmarker))
	end

	return
end

#Modify previously-generated plot:
#-------------------------------------------------------------------------------
#(Frequencies: in Hz; G: Open-loop characteristics)
#ωnperiods: in # of ωn periods
function update(mplot::InspectDR.Multiplot, fmin, fmax, tmax, ωnperiods, G::Xf1, annot=true)
	const npts = 500 #for plots
	const plot_mag = mplot.subplots[1]
	const plot_phase = mplot.subplots[3]
	const plot_step = mplot.subplots[2]
	const plot_stepnorm = mplot.subplots[4]
	const sys = Sys2(G) #Closed-loop response

	f = logspace(log10(fmin), log10(fmax), npts)
	y = xf_ol(2pi*f, G)
	BodePlots.update(plot_mag, plot_phase, f, y)
	plot_mag.ext = InspectDR.PExtents2D(NaN, NaN, -40, 100)
	plot_mag.markers = [] #Clear old markers
	plot_mag.atext = [] #Clear old annotation
	plot_phase.markers = [] #Clear old markers
	plot_phase.atext = [] #Clear old annotation
	if annot; update_bodeannot(plot_mag, plot_phase, G, sys.ωn); end

	#Absolute step:
	tstep = tmax/npts
	t = collect(0:tstep:tmax)
	y = abs(step_resp(sys, t))
	update_step(plot_step, t, y)

	#Relative step:
	xstep = ωnperiods/npts
	x = collect(0:xstep:ωnperiods)
	t = x./(sys.ωn/2pi)
	y = abs(step_resp(sys, t))
	update_step(plot_stepnorm, x, y)

	return mplot
end

#==Show functions
===============================================================================#

function Base.show(io::IO, s::Sys2)
	print(io, "Sys2(α=", SI(s.α), ", ζ=", SI(s.ζ), ", ωn=", SI(s.ωn), ")")
end


end #module
