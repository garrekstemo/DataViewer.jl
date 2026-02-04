module DataViewer

using CSV
using Dates
using DelimitedFiles
using FileWatching
using GLMakie
using CairoMakie
import QPS

include("common_functions.jl")  # AXIS_LABELS used by other modules
include("themes.jl")
include("loading_functions.jl")
include("live_plot.jl")
include("live_image.jl")

export live_plot, live_image, cleanup!
export load_mir, load_test_data

# Themes
export dataviewer_theme, dataviewer_colors
export apply_theme!, apply_theme_to_axis!
# Legacy aliases (deprecated)
export dataviewer_light_theme, dataviewer_light_colors

end # module
