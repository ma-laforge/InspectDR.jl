# Documentation for InspectDR extents

This file describes the scheme used to extract extents from data and combine them, along with user-specified extents.

## Comments

The extents scheme used in InspectDR is somewhat complex and is likely a bit buggy.

## Nomenclature:
 - A: used to represent `x, y, or z`. Ex: Aext represents: `xext, yext, and zext`.

## Different extents:
 - `ext_data`, `zext_data`: Maximum extents from all data in a given strip
 - `Aext_full`: `x/y/z` extents to be used when (NaN values: use `ext_data/zext_data`).
 - `Aext`: Current/active `x/y/z` extents (typically all finite).

## Operators:
 - `merge(dest, new)`: Overwrites/merges values from a PExtents1D/2D structure 
  - TODO: rename overwrite? Not overwriting dest, though.  Creates a new object.
 - `union`: Takes the FINITE union of two extents, ignoring NaNs.  Returns NaN when no finite extents are encountered
 - `getAextents_full():= merge(Aext_data, Aext_full) #Typically finite`
 - `setAextents(v): Aext <= merge(getAextents_full(), v) #Allows for NaN values in extents`

## Other functions:
 - `extents_finite`: Finds finite extents of a vector.  Returns infinite extents if none are found.  Returns NaN when no finite extents are encountered.
 - `extrema_nan`: Safe version of extrema.  Returns DNaN instead of throwing exception.  Ignores NaNs

## Usage:
 - User typically specifies `Aext_full`, leaving NaNs when data extents are to be used.
 - User can set CURRENT `x/y/z` extents by calling `setAextents`.

## NOTE:
Once extents are known, ticks are placed at "pretty" locations for the plot.

## TODO:
 - Improve how we store/manipulate extents
   - Fix get/set extents hierarchy to be more regular.
   - Fix/clarify functions such as merge, union, ...
 - Find a way to graphically show what is happening (not certain how):

Ex:

```
     Aext_data > overwrite(Aext_full)
Or

        |-- Aext_full
 Aext <-+-- Aext_data
```

