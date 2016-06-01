#InspectDR: Numeric formatting
#-------------------------------------------------------------------------------


#==Constants
===============================================================================#
const SUPERSCRIPT_NUMERALS = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹']
const SUPERSCRIPT_MINUS = '⁻'
const MINUS_SYMBOL = "−" #Longer than dash.
GRISU_FAILURE_WARNED = false


#==Main types
===============================================================================#

abstract RangeDisplayInfo

#Hints on how to display numbers in a linear range:
immutable LinearRangeDisplayInfo <: RangeDisplayInfo
	exp_min::Float64 #Base-10 exponent for max value
	exp_max::Float64 #Base-10 exponent for min value
	exp_step::Float64 #Base-10 exponent for step size
end
LinearRangeDisplayInfo() = LinearRangeDisplayInfo(0,0,0)

immutable NoRangeDisplayInfo <: RangeDisplayInfo; end

#=
#Notation: could be used to generate NumericFormatting objects.
immutable Notation{T}; end
typealias AutoNotation Notation{:auto}
typealias EngineeringNotation Notation{:eng}
typealias ScientificNotation Notation{:sci}
typealias SINotation Notation{:si}
typealias NativeNotation Notation{:nat}
Notation(t::Symbol) = Notation{t}()
=#

type NumericFormatting
	#eng::Bool #Whether to restrict to powers that are multiples of 3
	#engalign::Int Where to align decimal engieering values (decfloating=true)
	ndigits::Int #Number of digits to display/maximum digits
	#displayshortest::Bool #TODO
	decpos::Int #Fixed decimal position (value of exponent)
	decfloating::Bool #Ignores decpos - auto-detects 
	#expdisplay #TODO: how to display exponential portion (ex: x10³ / E3 / E+3 / e003 / k / x1000 / ...).
	showexp0::Bool #Show exponent when value is 0? TODO: make part of expdisplay?
end
NumericFormatting(; ndigits=3, decpos=1, decfloating=true, showexp0=false) =
	NumericFormatting(ndigits, decpos, decfloating, showexp0)

#How to display tick labels:
immutable TickLabelFormatting
	fmt::NumericFormatting
	splitexp::Bool #Only possible when !fmt.decfloating
end


type TickLabelStyle
	#notation::Notation #Is there a reason to support this???
	#expdisplay #TODO: how to display exponential portion
	ndigits::NullOr{Int} #Force # of digits displayed
	decpos::NullOr{Int} #Common exponent for all displayed numbers
	decfloating::Bool
	showexp0::Bool
	splitexp::Bool #Only possible when !decfloating
end
TickLabelStyle(; ndigits=nothing, decpos=nothing, decfloating=false, showexp0=false, splitexp=true) =
	TickLabelStyle(ndigits, decpos, decfloating, showexp0, splitexp)


#==Helper functions
===============================================================================#
finiteornan(x::Float64) = isfinite(x)? x: NaN


#==Other "constructors"
===============================================================================#

TickLabelFormatting(::NoRangeDisplayInfo) =
	TickLabelFormatting(NumericFormatting(ndigits=3, decfloating=true), false)

TickLabelFormatting(style::TickLabelStyle, rng::NoRangeDisplayInfo) =
	TickLabelFormatting(rng)

function TickLabelFormatting(style::TickLabelStyle, rng::LinearRangeDisplayInfo)
	decfloating = false
	decpos = style.decpos
	splitexp = style.splitexp #Only possible when !decfloating
	finite_expmin = finiteornan(rng.exp_min)
	finite_expmax = finiteornan(rng.exp_max)
	expmax = max(finite_expmin, finite_expmax)
	if !isfinite(expmax)
		expmax = rng.exp_step+1
	end

	if style.decfloating
		decfloating = true
		decpos = expmax
		splitexp = false #Not possible
	elseif nothing == decpos
		decpos = rng.exp_step
	end

	if !isfinite(decpos)
		decpos = 0
	end
	decpos = round(Int, decpos) #Just in case
	decpos = floor(Int, decpos/3)*3
	if rng.exp_step-decpos > 1; decpos += 3; end

	if decpos > 0 && expmax <= 4
		decpos = 0
	elseif decpos < 0 && rng.exp_step >= -4
		decpos = 0
	end

	ndigits = style.ndigits
	if nothing == ndigits
		ndigits = 3 #Default
		digitdelta1 = abs(expmax-rng.exp_step)
		digitdelta2 = abs(decpos-rng.exp_step)
		digitdelta = max(digitdelta1, digitdelta2)
		if isfinite(digitdelta)
			ndigits = round(Int, digitdelta)+1
		end
	end

	fmt = NumericFormatting(ndigits, decpos, decfloating, style.showexp0)
	return TickLabelFormatting(fmt, splitexp)
end


#==Functions
===============================================================================#

function warn_grisufail()
	global GRISU_FAILURE_WARNED
	if !GRISU_FAILURE_WARNED
		warn("Use of Grisu system failed.  Number display will be degraded.")
	end
	GRISU_FAILURE_WARNED = true
end

base10exp(v::Float64) = floor(log10(abs(v)))

#Everything before the exponential:
function print_formatted_mantgrisu(io::IO, ndigits::Int, decpos::Int, decfloating::Bool, val::Float64)
	if val < 0
		write(io, MINUS_SYMBOL)
	end
	if isinf(val)
		write(io, "∞")
		return 0
	elseif isnan(val)
		write(io, "NaN")
		return 0
	end

	#=WARNING:
	Rounding is inexact (too many digits), but should be OK for plots where
	steps/rounding positions are well controlled.
	=#
	len, pt, neg, buffer = Base.Grisu.grisu(val, Base.Grisu.PRECISION, ndigits+1)
	pdigits = pointer(buffer)
	if !decfloating && val!=0
		pt -= decpos #shift decimal point
	end

	grisuleft = len
	wholeleft = decfloating? 1: max(0, pt)
	fracleft = decfloating? ndigits-1 :ndigits-max(1, wholeleft)
	expleft = decfloating? pt-1: decpos

	if wholeleft < 1
		write(io, "0")
	else
		nchars = min(grisuleft, wholeleft)
		write(io, pdigits, nchars)
		pdigits += nchars
		wholeleft -= nchars
		grisuleft -= nchars

		for i in 1:wholeleft
			write(io, "0")
		end
	end

	if fracleft < 1
		return expleft
	end

	write(io, ".")

	leadingzeros = decfloating? 0: max(0, -pt)
	nzeros = min(leadingzeros, fracleft)
	for i in 1:nzeros
		write(io, "0")
	end
	fracleft -= nzeros

	nchars = min(grisuleft, fracleft)
	write(io, pdigits, nchars)
	fracleft -= nchars

	for i in 1:fracleft
		write(io, "0")
	end

	return expleft
end

function print_formatted_mant(io::IO, ndigits::Int, decpos::Int, decfloating::Bool, val::Float64)
	try
#		throw(:TESTME) #TODO
		return print_formatted_mantgrisu(io, ndigits, decpos, decfloating, val)
	catch #In case GRISU API changes:
		warn_grisufail()
		exp = base10exp(val)
		if !isfinite(exp)
			exp = 0
		else
			exp = round(Int, exp) #Needed in Int form
			exp += decpos
		end
		val /= 10.0^exp
		@printf(io, "%.3f", val) #Display something
		return exp
	end
end

function print_formatted_exp(io::IO, base::ASCIIString, exp::Int)
	exp_str = "$exp"
	write(io, "×")
	write(io, base)

	for c in exp_str
		if '-' == c
			write(io, SUPERSCRIPT_MINUS)
		elseif isnumber(c)
			idx = c - '0' + 1
			write(io, SUPERSCRIPT_NUMERALS[idx])
		end
	end
end

function print_formatted_exp(io::IO, fmt::NumericFormatting)
	@assert(!fmt.decfloating, "Cannot currently determine exponent when decimal is floating.")
	exp = fmt.decpos #Just showing exponential portion...
	if fmt.showexp0 || exp != 0
		print_formatted_exp(io, "10", fmt.decpos)
	end
end

function print_formatted(io::IO, fmt::NumericFormatting, val::Float64; showexp::Bool=true)
	exp = print_formatted_mant(io, fmt.ndigits, fmt.decpos, fmt.decfloating, val)
	if !isfinite(val); return; end
	if showexp && (fmt.showexp0 || exp != 0)
		print_formatted_exp(io, "10", exp)
	end
end

function Base.string(fmt::NumericFormatting, val::Float64; showexp::Bool=true)
	s = IOBuffer()
	print_formatted(s, fmt, val, showexp=showexp)
	d = s.data
	resize!(d, s.size)
	return bytestring(d)
end
Base.string(fmt::NumericFormatting, val::Real; showexp::Bool=true) =
	string(fmt, Float64(val), showexp=showexp)

#Get exponent string only:
function string_exp(fmt::NumericFormatting)
	s = IOBuffer()
	print_formatted_exp(s, fmt)
	d = s.data
	resize!(d, s.size)
	return bytestring(d)
end


#Last line
