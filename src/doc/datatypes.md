# Overview of InspectDR datatypes

## `DReal` vs `Float64`:
  - `Float64`: Used in API dealing with Gtk/Cairo coordinates.
  - `DReal`: Used in API dealing with plot data itself
(Attempt to reduce code bloat/different code paths by using concrete data type
in internal data structures/algorithms... despite potential inefficiencies).
