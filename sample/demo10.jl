#Demo 10: Mixed-signal "Simulation"
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

line_default = line(color=blue, width=3)
line_overlay = line(color=red, width=3)


#Input data
#-------------------------------------------------------------------------------
ppcycle = 40 #Points per cycle (divisible by 4 to get notches)
T=1/60 #Clock period
ncycles = 15
VSUPPLY = 120 #VRMS - mains
VREG = 80 #Rectifier voltage
τ = T/2 #Time constant for discharge (output load)


#=="Simulation" (really rudimentary to keep things simple)
===============================================================================#
mains_fn(t) = VSUPPLY*sqrt(2)*cos.(2pi*(t./T))
#Find time where mains crosses given threshold:
mains_xfn(thresh) = acos(thresh/(VSUPPLY*sqrt(2)))*(T/(2pi))

function update_discharge(vreg, Δt, i)
	if 0==vreg[i] #On discharge cycle:
		vreg[i] = VREG*exp(-Δt/τ)
	end
end

#Compute info for a single cycle:
#-------------------------------------------------------------------------------
t = collect(range(0, stop=T, length=ppcycle+1)[1:end-1]) #Time
npts = length(t); hpts = div(npts, 2) #npts should match ppcycle

mains = mains_fn(t)
mains_rect = abs.(mains)
regactive = mains_rect .> VREG
regactive_sig = regactive * 1.0 #Not bool
vreg = regactive_sig*VREG #Voltage @ rectifier - not yet filtered
#Emulate filtering/discharge:
	#Really dumb algorithm:
	d_start = mains_xfn(VREG) #Start of 1st discharge cycle
#	d_end = d_start+2*(T/4-d_start)
	for i in 1:hpts
		update_discharge(vreg, t[i]-d_start, i)
	end
	d_start += T/2 #Next discharge cycle
	for i in hpts:npts
		update_discharge(vreg, t[i]-d_start, i)
	end

#Extend data for multiple cycles:
#-------------------------------------------------------------------------------
t = collect(range(0, stop=ncycles*T, length=ncycles*ppcycle+1)[1:end-1]) #Time
mains = repeat(mains, outer=ncycles)
mains_rect = repeat(mains_rect, outer=ncycles)
vreg = repeat(vreg, outer=ncycles)
regactive_sig = repeat(regactive_sig, outer=ncycles)

gaterange_list = [4.6:6.1, 9.4:12.9] #In # of cycles
gate_b = 1.0 .+ zero(t) #Active low
for gaterange in gaterange_list
	irange = ppcycle*gaterange
	istart = round(Int, minimum(irange))
	istop = round(Int, maximum(irange))
	gate_b[istart:istop] .= 0
end
vrect_gated = vreg.*gate_b
vrect_thresh = zero(t) .+ VREG


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot(title="Mixed-Signal \"Simulation\": $(VREG)V Regulator")
nstrips = 4

plot = add(mplot, InspectDR.transientplot([:lin for i in 1:nstrips],
	title="", #No title - use strip labels instead
	ylabels=["Potential (V)" for i in 1:nstrips]
))
plot.layout[:enable_legend] = true
plot.layout[:halloc_legend] = 150
ystriplabels = plot.annotation.ystriplabels #Shortcut
yext_digital = InspectDR.PExtents1D(-0.2, 1.2) #"Digital" signals (pad)
yext_output = InspectDR.PExtents1D(0,1.2*VREG) #Ouptut: pad above

#Add waveforms & overlay useful signals:
push!(ystriplabels, "Regulator Output")
plot.strips[1].yext_full = yext_output
	wfrm = add(plot, t, vreg, id="regulated", strip=1); wfrm.line = line_default
	#Overlay gated output onto internal:
	wfrm = add(plot, t, vrect_gated, id="output (gated)", strip=1); wfrm.line = line_overlay

push!(ystriplabels, "Digital Sensor Output & Control Signals")
plot.strips[2].yext_full = yext_digital
	wfrm = add(plot, t, regactive_sig, id="|mains|>thresh", strip=2); wfrm.line = line_default
	#Overlay gate onto gated output:
	wfrm = add(plot, t, gate_b, id="gate_b", strip=2); wfrm.line = line_overlay

push!(ystriplabels, "Rectifier Ouptut")
	wfrm = add(plot, t, mains_rect, id="|mains|", strip=3); wfrm.line = line_default
	#Overlay threshold onto |mains|, for convenience
	wfrm = add(plot, t, vrect_thresh, id="thresh", strip=3); wfrm.line = line_overlay

push!(ystriplabels, "Input: Mains")
	wfrm = add(plot, t, mains, id="mains", strip=4); wfrm.line = line_default

gplot = display(InspectDR.GtkDisplay(), mplot)

mplot.layout[:halloc_plot] = 700; mplot.layout[:valloc_plot] = 600
InspectDR.write_png("export_rectifier.png", mplot)

:DONE
