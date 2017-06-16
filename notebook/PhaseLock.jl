
if !isdefined(:BodePlots)
include("BodePlots.jl")
end

module PhaseLock

import Graphics.BoundingBox
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
mutable struct Xf1
	K::Float64
	ωz::Float64
	ωp::Float64
end
Xf1(;K=1, ωz=1, ωp=1) = Xf1(K, ωz, ωp)

#2nd order system (standard form):
mutable struct Sys2
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
	const yext_step = InspectDR.PExtents1D(0, 1.6)

	mplot = InspectDR.Multiplot(title="PLL Characteristics")
	Δh = mplot.layout[:valloc_title]
	mplot.layout[:ncolumns] = 2
	#Bode plot looks better with wider aspect ratio:
	mplot.layout[:halloc_plot] = w; mplot.layout[:valloc_plot] = h/2

	plot_step = add(mplot, InspectDR.Plot2D)
	plot_bode = add(mplot, BodePlots.new(InspectDR.Plot))
	plot_stepnorm = add(mplot, InspectDR.Plot2D)

	#Control where plots render:
	plot_step.plotbb = BoundingBox(0, w, Δh, Δh+h/2)
	plot_stepnorm.plotbb = BoundingBox(0, w, Δh+h/2, Δh+h)
	plot_bode.plotbb = BoundingBox(w, 2w, Δh, Δh+h)

	#Add title to bode plot:
	a = plot_bode.annotation
		a.title = "Open-Loop Characteristics"
	plot_bode.strips[1].yext_full = InspectDR.PExtents1D(-40, 100)

	#Step-response plot:
	a = plot_step.annotation
		a.title = "Step Response"
		a.xlabel = "Time (s)"
		a.ylabels = ["Amplitude"]
	plot_step.strips[1].yext_full = yext_step
#		plot_step.layout.grid = grid(vmajor=true, vminor=true, hmajor=false)

	a = plot_stepnorm.annotation; lyt = plot_stepnorm.layout
		a.title = ""; lyt.layout[:valloc_top] = 8 #subtitle/space
		a.xlabel = "ωn*t (rad)"
		a.ylabels = ["Amplitude"]
	plot_stepnorm.strips[1].yext_full = yext_step
	
	return mplot
end

#Modify previously-generated Bode plot (base algorithm):
#-------------------------------------------------------------------------------
function update_step(plot::InspectDR.Plot2D, t::Vector, y::Vector)
	const ldata = line(color=blue, width=3, style=:solid)

	plot.data = [] #Clear old data

	#Reset extents:
	plot.xext = InspectDR.PExtents1D()
	plot.strips[1].yext = InspectDR.PExtents1D()

	wfrm = add(plot, t, mag(y))
		wfrm.line = ldata

	return plot
end

#Update annotation on Bode plot (enabled=false to clear annotation):
#-------------------------------------------------------------------------------
function update_bodeannot(plot_bode::Plot2D, G::Xf1, ωn)
	const lmarker = line(style=:dash, width=2.5)
	const lmarker_light = line(style=:solid, width=2.5, color=RGB24(.4,.4,.4))
	const fp = G.ωp/(2pi)
	const fz = G.ωz/(2pi)
	const fn = ωn/(2pi)
	const ω0 = ω_0(G)
	const f0 = ω0/(2pi)
	const phase0 = phase(xf_ol([ω0], G)[1]) #Unity gain phase

	#Add specialized annotation
	afont = plot.layout[:font_annotation]

	#Add annotation to Magnitude plot:
#	add(plot_bode, atext("0dB", y=0, xoffset_rel=0.5, yoffset=3, font=afont, align=:bc, strip=1))
	add(plot_bode, hmarker(0, lmarker_light, strip=1))

	polelist = [("fp", fp), ("fz", fz), ("fn", fn), ("f0", f0)]
	#Hack if f0>0: TODO: Fix bug where annotating text @ 0 on log plot causes glitch. 
	for (id, f) in polelist
		if isfinite(f) && f > 0
			fstr = id * "=" * SI(f) * "Hz"
			add(plot_bode, atext(fstr, x=f, xoffset=-3, yoffset_rel=0.5, font=afont, angle=-90, align=:bc, strip=1))

			#Add vertical markers to both plots:
			add(plot_bode, vmarker(f, lmarker, strip=0))
		end
	end

	#Add annotation to Phase plot:
	if isfinite(phase0)
		pmargin = 180+phase0
		fstr = "PM=" * @sprintf("%.1f°", pmargin)
		add(plot_bode, atext(fstr, y=(phase0-180)/2, xoffset_rel=0.5, font=afont, align=:cc, strip=2))
		add(plot_bode, hmarker(phase0, lmarker, strip=2))
	end

	return
end

#Modify previously-generated plot:
#-------------------------------------------------------------------------------
#(Frequencies: in Hz; G: Open-loop characteristics)
#ωnperiods: in # of ωn periods
function update(mplot::InspectDR.Multiplot, fmin, fmax, tmax, ωnperiods, G::Xf1, annot=true)
	const npts = 500 #for plots
	const plot_step = mplot.subplots[1]
	const plot_bode = mplot.subplots[2]
	const plot_stepnorm = mplot.subplots[3]
	const sys = Sys2(G) #Closed-loop response

	f = logspace(log10(fmin), log10(fmax), npts)
	y = xf_ol(2pi*f, G)
	BodePlots.update(plot_bode, f, y)

	#Reset extents/annotation:
	plot_bode.xext = InspectDR.PExtents1D()
	plot_bode.strips[1].yext = InspectDR.PExtents1D()
	plot_bode.userannot = [] #Clear old markers/text annotation
	if annot; update_bodeannot(plot_bode, G, sys.ωn); end

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
