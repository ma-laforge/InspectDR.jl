#InspectDR: Some extra docstrings when not practical to have with declaration
#-------------------------------------------------------------------------------

write_docstring_generator(ext) = """
   write_$ext(path::String, ::Union{Plot, MultiPlot, GtkPlot})

Generate .$ext image from `Plot`/`Multiplot` object, and write it to file.
"""

@doc write_docstring_generator(:png) write_png
@doc write_docstring_generator(:svg) write_svg
@doc write_docstring_generator(:eps) write_eps
@doc write_docstring_generator(:pdf) write_pdf


@doc """
    clear_data(plot::Union{Plot, Multiplot})
    clear_data(plot::GtkPlot; refresh_gui=true)

Clear all data from `Plot`/`Multiplot` structure.  Also refresh GUI if requested.
""" clear_data

#Last line
