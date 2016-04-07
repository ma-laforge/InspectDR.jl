using InspectDR
using Colors

#==Input constants
===============================================================================#
black = RGB24(0, 0, 0)
white = RGB24(1, 1, 1)
red = RGB24(1, 0, 0)
green = RGB24(0, 1, 0)
blue = RGB24(0, 0, 1)


#==Input data
===============================================================================#

test = :test1

#Dataset 1: Simple sine wave
#-------------------------------------------------------------------------------
if :test1 == test
xmax = 2000
x = collect(0:xmax)
#y = 10*sin((4*2pi/100).*x) +10
y = sin((4*2pi/xmax).*x)
end

#Dataset 2: Large data experiment
#-------------------------------------------------------------------------------
if :test2 == test
import EDAData
using FileIO2
home = ENV["HOME"]
datapath = "$home/data/cppsimdata"
reader = EDAData._open(File(:tr0, joinpath(datapath, "sigmadeltaexample.tr0")))
sig = read(reader, "v")
close(reader)
#Data read
x = sig.x; y = sig.y
end

#Dataset 3: Controlled HF noise
#-------------------------------------------------------------------------------
function gennoise(xv, yv; step=.01, npts=20, lo=0, hi=1)
	xmax = xv[end]
	xnew = xmax+collect(step:step:(npts*step))
	ynew = similar(xnew)
	v = Float64[lo, hi]
	for i in 1:length(ynew)
		ynew[i] = v[(i&0x1)+1]
	end
	append!(xv, xnew)
	append!(yv, ynew)
end

function addpts(ynew, xv, yv; step=1.0)
	xmax = xv[end]
	npts = length(ynew)
	xnew = xmax+collect(step:step:(npts*step))
	append!(xv, xnew)
	append!(yv, ynew)
end

#Generate dataset:
if :test3 == test
	x = Float64[0]
	y = Float64[0]
	addpts(Float64[1,1,1,0,0], x,y)
	gennoise(x,y)
	addpts(Float64[0,1,1,1,0,0], x,y)
	gennoise(x,y)
	addpts(Float64[1,1,1,0,0], x,y)
	gennoise(x,y)
	addpts(Float64[1,1,1,0,0], x,y)
end


#==Generate plot
===============================================================================#
plt = InspectDR.GtkPlot()


#Control extents:
#-------------------------------------------------------------------------------
xmax = 2e-3/20
#xmax = 2e-3
#xmax = .22
#plt.src.ext = InspectDR.PExtents2D(0, xmax, -0.5,2.5)
#plt.src.ext = InspectDR.PExtents2D(NaN, NaN, -0.5,2.5)
@show plt.src.ext

style = :dashdot
#style = :solid
w = InspectDR._add(plt.src, x, y+1)
w.line = InspectDR.line(color=blue, width=1, style=style)
w = InspectDR._add(plt.src, x, y-1)
w.line = InspectDR.line(color=red, width=5, style=style)
plt.src.xres=1000 #Force resolution

InspectDR._display(plt)
@show plt.src.ext_max



:DONE
