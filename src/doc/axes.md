# InspectDR: Axes Documentation

This file describes the scheme used describe axes and scales.

## Types:
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

## Comments
HUGE room for improvement in function/type names, and how solution is broken down.  Very confusing patchwork.

## TODO:


