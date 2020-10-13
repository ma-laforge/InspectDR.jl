# InspectDR: Advanced usage

<a name="DisplaySystem"></a>
## Display/Render system

InspectDR provides the `GtkDisplay` object derived from `Base.Multimedia.Display`.  `GtkDisplay` is used in combination with `Base.display()`, to spawn a new instance of a GTK-based GUI.

TODO: Explain display/rendering system in more detail

<a name="CustomGenerators"></a>
## Custom plot generators

TODO

<a name="CustomStylesheets"></a>
## Custom stylesheets

Custom stylesheets are added by extending `InspectDR.getstyle()`, as done in [stylesheets.jl](../src/stylesheets.jl) (Search for: `StyleID{:screen}` & `StyleID{:IEEE}`).

