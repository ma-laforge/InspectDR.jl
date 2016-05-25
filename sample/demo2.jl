#Demo 2: Reflection coefficients
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
μ0 = 4pi*1e-7 #F/m
ϵ0 = 8.854e-12 #H/m


#Input data
#-------------------------------------------------------------------------------
fmax = 10e9
fstep = 50e6
f = collect(0:fstep:fmax)
ℓ = 50e-3 #Meters
ZL = Float64[1e6, 377, 60.0]
_colors = [blue, red, green]


#==Equations
===============================================================================#
Γ(Z; Zref::Real=50.0) = (Z - Zref) ./ (Z + Zref)
#ZC: Characteristic impedance
#ZL: Load impendance (termination)
function Zline(ℓ::Real, f::Vector, ZL::Number; ZC::Number=50.0, α::Real=0, μ::Real=μ0, ϵ::Real=ϵ0)
	j = im
	β = f*(2pi*sqrt(μ*ϵ))
	γ = α+j*β
	tanh_γℓ = tanh(γ*ℓ)
	return ZC*(ZL+ZC*tanh_γℓ)./(ZC+ZL*tanh_γℓ)
end
function Γline(ℓ::Real, f::Vector, ZL::Number; ZC::Number=50.0, Zref::Number=50.0, α::Real=0, μ::Real=μ0, ϵ::Real=ϵ0)
	return Γ(Zline(ℓ, f, ZL; ZC=ZC, α=α, μ=μ, ϵ=ϵ), Zref=Zref)
end

#Calculations
#-------------------------------------------------------------------------------
Γload = []
for ZLi in ZL
	_Γ = Γline(ℓ, f, ZLi, ZC=40)
	push!(Γload, _Γ)
end


#==Generate plot
===============================================================================#
mplot = InspectDR.Multiplot()

if false #"Smith plot"
	plot = add(mplot, InspectDR.Plot2D)
		a = plot.annotation
		a.title = "Smith plot"

	i = 1
	for i in 1:length(Γload)
		wfrm = add(plot, real(Γload[i]), imag(Γload[i]))
		wfrm.line = line(color=_colors[i], width=1)
	end

	plot.ext_full = InspectDR.PExtents2D(xmin=-1,xmax=1,ymin=-1,ymax=1)
else #Magnitude
	mplot.ncolumns = 2
	plot_linf = InspectDR.Plot2D()
		plot_linf.axes = InspectDR.axes(:lin, :dB20)
		plot_linf.ext_full = InspectDR.PExtents2D(ymax=5)
#		plot_linf.layout.legend.enabled=true
	plot_logf = InspectDR.Plot2D()
		plot_logf.axes = InspectDR.axes(:log10, :dB20)
		plot_logf.ext_full = InspectDR.PExtents2D(xmin=10e6,ymax=5)
		plot_logf.layout.grid = grid(vmajor=true, vminor=true, hmajor=true)
		plot_logf.layout.legend.enabled=true

	plotlist = [plot_linf, plot_logf]
#	plotlist = [plot_logf]
#	plotlist = [plot_linf]

	for i in 1:length(Γload)
		for plot in plotlist
			wfrm = add(plot, f, Γload[i], id="ZL=$(ZL[i])")
			wfrm.line = line(color=_colors[i], width=1)
		end
	end

	for plot in plotlist
		add(mplot, plot)
		a = plot.annotation
		a.title = "Reflection Coefficient (Γ)"
		a.xlabel = "Frequency (Hz)"
		a.ylabel = "Magnitude (dB)"
	end
end

gplot = display(InspectDR.GtkDisplay(), mplot)

:DONE
