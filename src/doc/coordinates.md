# Documentation for InspectDR coordinate systems & transforms

## Transformations between coordinate systems:
```
         nlxfrm      lxfrm
	data/ -----> axis -----> device
	world                    /view

	where:
		lxfrm is a linear transformation
		nlxfrm is potentially a nonlinear transformation
```

  - Data coordinates hold whichever units is associated with the data (D).
  - Axis units are transformations of D (ex: D, log(D), dB20(D), ...)
  - Device units can typically be thought of in pixels.

## Auxiliary transformations:
```
	     nlxfrm
	axis -----> readable
                (read)
	Readable coordinates are basically axis coordinates in a readable form.
	Ex (for log10-X scale): X{axis}=2.5 --> X{read}=10^2.5
```

## PExtents2D vs BoundingBox:
  - PExtents2D: Extents of data (data coordinate system).
  - BoundingBox: Extents of graphical element ("device" coordinate system).

## About extents:
Extents are typically stored using user-level coordinates (`USER`).
When drawing the plot, extents are manipulated in a transformed coordinate
system (`XFRM`).  For example, `XFRM` coordinates of a log-x plot are given by
`XFRM=log10(USER)`.

  - `ext_data::PExtents2D`: Maximum extents of data
  - `ext_full::PExtents2D`: Defines "full" zoom when combined with `ext_data`.
(Set fields to `NaN` to keep `ext_data` values)
  - `ext::PExtents2D` #Current/active extents
  - `setextents(::Plot2D, ::PExtents2D)`: Also invalidates rendered plot.
  - `getextents(...)`: Complementary accessor.

## About bounds:
  - `plotbounds(...)`: Bounding box of entire plot.
  - `databounds(...)`: Bounding box of entire data area (multiple graph strips).
  - `graphbounds(...)`: Bounding box of individual graph strip.
