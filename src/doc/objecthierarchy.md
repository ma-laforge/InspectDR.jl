# InspectDR: Object Hierarchy

## Axis/Scale objects:
 - AxisScale: Abstract
 - LinScale{1/:dB10/:dB20/...}: Scale is linear despite having to apply nonlinear transform.
 - LogScale{:e/1/10/...}: Different log scales.
 - InputXfrm1D
 - InputXfrm2D
 - InputXfrm1DSpec: Used to generate specialized (efficient) code for a transform.

## Deprecated?
 - `CoordSystem, AxisCoord, NormCoord, DataCoord, TypedCoord, AnnotationCoord`
  - Probably wanted to tag coordinates depending on where they were on the chain of transforms.
  - Maybe bring back a version of them in order to simplify how InspectDR deals with coordinates.

# Stacked, multi-strip plots
In order to support stacked graphs with independent y-axes (tied to the same x-axis), specifying axis scales is a bit involved:

 - `InspectDR.Plot2D.xscale` controls the x-axis scale.
 - `InspectDR.Plot2D.strips[STRIP_INDEX].yscale` controls the y-axis scale.


