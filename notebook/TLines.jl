if !isdefined(:BodePlots)
include("BodePlots.jl")
end

module TLines
import BodePlots

using InspectDR
import InspectDR: Plot2D
using NumericIO
using Colors

typealias VecOrNum Union{Vector,Number}
typealias VecOrReal Union{Vector,Real}

#Colour constants
#-------------------------------------------------------------------------------
const black = RGB24(0, 0, 0); const white = RGB24(1, 1, 1)
const red = RGB24(1, 0, 0); const green = RGB24(0, 1, 0); const blue = RGB24(0, 0, 1)

#Physics constants
#-------------------------------------------------------------------------------
const μ0 = 4pi*1e-7 #F/m
const ϵ0 = 8.854e-12 #H/m

#Convenience aliases
#-------------------------------------------------------------------------------
mag(x) = abs(x); phase(x) = rad2deg(angle(x))
SI(x) = formatted(x, :SI, ndigits=3)
const j = im


#==Equations
===============================================================================#
#=NOTE:
 - Not particularly optimized for speed.
 - Not particularly complete/well named set of functions.
=#

#Compute propagation constant of a transmission line
function γline(f::VecOrReal; α::VecOrReal=0, μ::Real=μ0, ϵ::Real=ϵ0)
	β = f*(2pi*sqrt(μ*ϵ))
	return α+j*β
end

#Compute reflection coefficient of a given impedance
#Zref: Reference impedance for the reflection coefficient
Γ(Z::VecOrNum; Zref::Real=50.0) = (Z - Zref) ./ (Z + Zref)

#Compute impedance of a loaded transmission line
#ZC: Characteristic impedance (not currently modelling f-dependence)
#ZL: Load impendance (termination)
function Zline(ZC::Number, γ::VecOrNum; ZL::VecOrNum=Inf64, ℓ::Real=0.0)
	tanh_γℓ = tanh(γ*ℓ)
	return ZC*(ZL+ZC*tanh_γℓ)./(ZC+ZL.*tanh_γℓ)
end


#==Main functions
===============================================================================#
function newplot()
	const w = 500; const h = w/1.6 #Select plot width/height

	mplot = InspectDR.Multiplot(title="Loaded Transmission Line")
	mplot.ncolumns = 2
	#Bode plot looks better with wider aspect ratio:
#	mplot.wplot = w; mplot.hplot = h/2
	#... But not Smith chart.

	plot_mag = add(mplot, InspectDR.Plot2D)
	plot_smith = add(mplot, InspectDR.Plot2D)
	plot_phase = add(mplot, InspectDR.Plot2D)
	htitle = plot_mag.layout.htitle #Restore later

	#Bode plot:
	BodePlots.init(plot_mag, plot_phase)

	#Add title to bode plot:
	a = plot_mag.annotation; lyt = plot_mag.layout
		lyt.htitle = htitle #Restore space for subtitle
		a.title = "Reflection Coefficient (Γ)"

	#Smith chart:
	plot_smith.axes = InspectDR.axes(:smith, :Z, ref=50)
	a = plot_smith.annotation
		a.title = "Z-Smith Chart"
		a.xlabel = "Real(Γ)"
		a.ylabel = "Imaginary(Γ)"
	plot_smith.ext_full = InspectDR.PExtents2D(xmin=-1.2,xmax=1.2,ymin=-1.2,ymax=1.2)

	return mplot
end

#Modify previously-generated plot:
#-------------------------------------------------------------------------------
#(Frequencies: in Hz)
function update(mplot::InspectDR.Multiplot, fmin, fmax, ltype::Symbol, R, L, C, ℓ, ZC, αdB)
	const npts_bode = 500
	const ldata = line(color=blue, width=3, style=:solid)
	const plot_mag = mplot.subplots[1]
	const plot_smith = mplot.subplots[2]
	const plot_phase = mplot.subplots[3]
	const αDC = (20/log(10)) * αdB #Nepers/m

	#Add some frequency dependence to α (makes plot more interesting):
	const fref = 10e9; αref = 2*αDC
	fdepα(f, αDC) = αDC + (αref/sqrt(fref))*sqrt(f)

	#How to compute load impedance:
	Zload_shunt(jω,R,L,C) = 1./(1./R+1./(jω*L)+jω*C)
	Zload_series(jω,R,L,C) = R+jω*L+1./(jω*C)
	Zload = :shunt == ltype? Zload_shunt: Zload_series

	#Generate Bode plot:
	f = logspace(log10(fmin), log10(fmax), npts_bode)
	jω = j*2pi*f
	y = Γ(Zline(ZC, γline(f, α=fdepα(f, αDC)), ZL=Zload(jω,R,L,C), ℓ=ℓ))
	BodePlots.update(plot_mag, plot_phase, f, y)
	plot_mag.ext = InspectDR.PExtents2D(NaN, NaN, -20, 0)
	plot_phase.ext = InspectDR.PExtents2D(NaN, NaN, -200, 200)

	#Generate Smith chart:
	plot_smith.data = [] #Clear old data
#	plot_smith.ext_full = InspectDR.PExtents2D() #Reset full extents
	β = imag(γline(fmax))
	Θ = β * ℓ; nrev = Θ/pi #revs around the chart
	npts = round(Int, 20*nrev) #Ensure sufficient # of points
	f = collect(linspace(fmin, fmax, npts))
	jω = j*2pi*f
	y = Γ(Zline(ZC, γline(f, α=fdepα(f, αDC)), ZL=Zload(jω,R,L,C), ℓ=ℓ))
	wfrm = add(plot_smith, f, y)
	wfrm.line = ldata

	#Clear old annotation/markers:
	for p in [plot_mag, plot_phase]
		p.markers = []
		p.atext = []
	end

	return mplot
end

end #module
