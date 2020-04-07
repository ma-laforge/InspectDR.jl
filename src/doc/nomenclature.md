# InspectDR: Nomenclature 

## data/aloc/axis/dev
Identifies coordinates systems
  - data: Raw input data coordinates.
  - aloc: Coordinates used to LOCATE input data on axes.
  - axis: Readable coordinates (on axes).
  - dev: Device coordinates (pixels).

TODO: create other coordinate systems for backends that support more than just
pixels as a device coordinate?  Ex: maybe some backends also support Desktop
publishing "Points" natively when drawing.

## Plot/Graph/Strip/Data area
  - Plot area: Entire canvas for a single plot, including annotation & legends.
    (A multiplot has multiple plot canvases)
  - Graph area: A viewport where data is graphed.
  - Strip: Vertically stacked graphs with common x-axes.
  - Data area: rectangular area encompassing graph area of all strips.
  - plotbb: bounding box of entire plot.
  - graphbb: bounding box of a single graph area.
  - databb: bounding box encompassing all graph areas.

## RPlot2D/RStrip2D
  - Cache for bounds, current extents, text formatting, transforms, etc.
  - "Evaluated" information about all plots/strips.
  - Structures intended for ease of access for rendering functions, at expense
    of data duplication (Assumes data will not get corrupted while rendering).

## CairoBufferedPlot
Used to buffer portions of plot for better GUI response times
