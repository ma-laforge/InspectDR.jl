if !isdefined(:BodePlots)
include("BodePlots.jl")
end

module DSPFilters
import BodePlots

using DSP
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


#==Equations
===============================================================================#


#==Main functions
===============================================================================#
function newplot()
	const w = 500
	mplot = InspectDR.Multiplot(title="Filter Response")
	#Mag/phase plots look better with wider aspect ratio:
	mplot.wplot = w; mplot.hplot = w/2.3
	mplot.ncolumns = 1

	plot_mag = add(mplot, InspectDR.Plot2D)
	plot_phase = add(mplot, InspectDR.Plot2D)

	#Initialize as Bode plot:
	BodePlots.init(plot_mag, plot_phase)

	#Use linear frequency instead of actual Bode plot:
	plot_mag.axes = InspectDR.axes(:lin, :dB20)
	plot_phase.axes = InspectDR.axes(:lin, :lin)


	return mplot
end

#Modify previously-generated plot:
#-------------------------------------------------------------------------------
#TODO: Look for off by 1 errors (esp. for FFT vector lengths, etc).
#(Frequencies: in Hz)
function update(mplot::InspectDR.Multiplot, fmax, filttypeid::Symbol, filtimplid::Symbol, order, fl, fh, passrip, stoprip)
	const npts = 500
	const ldata = line(color=blue, width=3, style=:solid)
	const lspec = line(color=red, width=1, style=:solid) #Spectrum
	const plot_mag = mplot.subplots[1]
	const plot_phase = mplot.subplots[2]
	const rlow = 1/100; const rhigh = 1-rlow
	limfreqr(ratio) = clamp(ratio, rlow, rhigh)

	if fh < fl #Re-order fl/fh:
		(fl, fh) = (fh, fl)
	end

	#Generate filter type object:
	filttype = nothing 
	if :highpass == filttypeid
		filttype = Highpass(limfreqr(fh/fmax))
	elseif :bandstop == filttypeid
		filttype = Bandstop(limfreqr(fl/fmax), limfreqr(fh/fmax))
	elseif :bandpass == filttypeid
		filttype = Bandpass(limfreqr(fl/fmax), limfreqr(fh/fmax))
	else #:lowpass
		filttype = Lowpass(limfreqr(fl/fmax))
	end

	#Generate filter implementation object
	filtimpl = nothing
	if :elliptic == filtimplid
		filtimpl = Elliptic(order, passrip, stoprip)
	elseif :chebyshevpass == filtimplid
		filtimpl = Chebyshev1(order, passrip)
	elseif :chebyshevstop == filtimplid
		filtimpl = Chebyshev2(order, stoprip)
	else
		filtimpl = Butterworth(order)
	end

	_filt = digitalfilter(filttype, filtimpl)

	#Generate mag/phase plot of discrete-time system:
	#TODO: find proper name for frequency variable.
	fz = collect(linspace(0, pi, npts))
	tf_graph = freqz(_filt, fz)
	f = fz*(fmax/pi)
	BodePlots.update(plot_mag, plot_phase, f, tf_graph)
	plot_mag.ext = InspectDR.PExtents2D(NaN, NaN, -90, 10)
	plot_phase.ext = InspectDR.PExtents2D(NaN, NaN, -200, 200)


	#Overlay spectrum using random data:
	xin = rand(100000)
	xout = filt(_filt, xin)
	spec = rfft(xout)/sqrt(length(xin)/2)
	fz = collect(linspace(0, pi, length(spec)))
	f = fz*(fmax/pi)
	wfrm = add(plot_mag, f, spec)
	wfrm.line = lspec

	#Hack to plot spectrum *before* (under) frequency graph:
	plot_mag.data = reverse(plot_mag.data)

	return mplot
end

end #module
