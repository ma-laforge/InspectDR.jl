# InspectDR: User-Level Interfaces 

## Exported Interface

## Extended Interface
Displaying a `Plot` object:
```julia
	Base.display(d::InspectDR.GtkDisplay, p::Plot) #Gtk mutltiplot window
```

Closing a Gtk plot window:
```julia
	Base.close(::GtkPlot)
```

Writing plot to `IO` stream:
```julia
	Base.show(::IO, ::MIME, ::Plot2D)
```
for the following `MIME`s:
  - `MIME"image/png"`
  - `MIME"image/svg+xml"`
  - `MIME"image/eps"`
  - `MIME"application/pdf"`

## Unexported interface
Supported plot types:
  - `InspectDR.Multiplot()`: Figure supporting multiple plots
  - `InspectDR.Plot2D <: Plot`: 2D plot object

Convenience functions:
  - `write_png(path, ::Plot)`
  - `write_svg(path, ::Plot)`
  - `write_eps(path, ::Plot)`
  - `write_pdf(path, ::Plot)`

Other:
  - `refresh(::PlotWidget)`
  - `refresh(::GtkPlot)`
  - `clearsubplots(::GtkPlot)`



