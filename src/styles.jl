#InspectDR: Functionality for user-overwritable styles (ex: used in stylesheets)
#-------------------------------------------------------------------------------

#=
Also contains mechanism to overwrite certain properties of a structure.
=#

#==Main types
===============================================================================#
abstract type AbstractStyle end #Type that can be made into a "StyleType"

#Mechanism to overwrite only certain properties from a function call:
struct KeepPrevType end #Keep previous value
const KEEP_PREV = KeepPrevType()

struct UseDefaultType end #Use style default
const USE_DFLT = UseDefaultType()

#Defines a "style" object (to implement user-overwritable styles):
mutable struct StyleType{T<:AbstractStyle}
	values::T #Active values
	defaults::T #Defaults for this style
	overwrite::Set{Symbol} #Masks out which elements user wishes to overwrite
end
StyleType(defaults::T) where T<:AbstractStyle =
	StyleType(deepcopy(defaults), defaults, Set{Symbol}([]))
StyleType(values::T, defaults::T) where T<:AbstractStyle =
	StyleType(values, defaults, Set{Symbol}([]))


#==Main functions
===============================================================================#
overwriteprop!(s, key::Symbol, value::UseDefaultType) = nothing #Don't change value
overwriteprop!(s, key::Symbol, value::KeepPrevType) = nothing #Don't change value
function overwriteprop!(s, key::Symbol, value)
	value = convert(typeof(getfield(s, key)), value) #Need proper type
	setfield!(s, key, value)
end

#Want to use default, so ensure key not in overwrite "set"
function overwritestyleattrib(overwrite::Set{Symbol}, key::Symbol, value::UseDefaultType)
	if key in overwrite
		pop!(overwrite, key)
	end
	return
end
#Make sure marked as overwritten:
overwritestyleattrib(overwrite::Set{Symbol}, key::Symbol, value) = push!(overwrite, key)
#Mark given keys as overwritten:
markoverwritten!(s::StyleType, keylist::Set{Symbol}) = union!(s.overwrite, keylist)

function overwrite!(s::StyleType, key::Symbol, value)
	overwriteprop!(s.values, key, value)
	overwritestyleattrib(s.overwrite, key, value)
end

#Synchronize values with defaults if they are out of sync.
function refresh!(s::StyleType{T}) where T
	proplist = fieldnames(T)
	for key in proplist
		if !(key in s.overwrite)
			value = deepcopy(getfield(s.defaults, key))
			setfield!(s.values, key, value)
		end
	end
	return
end

#Changes the default to the given value, and refreshes .value fields, if requested
#TODO: rename setdefaults!()??
function setstyle!(s::StyleType{T}, value::T; refresh::Bool=true) where T<:AbstractStyle
	s.defaults = value
	if refresh
		refresh!(s)
	end
	return
end


#==Mutators
===============================================================================#
Base.setindex!(s::StyleType, value, key::Symbol) = overwrite!(s, key, value)
Base.getindex(s::StyleType, key::Symbol) = getfield(s.values, key)

#Last line
