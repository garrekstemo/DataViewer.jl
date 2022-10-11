module DataStream

using CSV
using DataFrames
using FileWatching
using GLMakie
using LVM

include("stream.jl")
include("loading_funcs.jl")
include("themes.jl")

export dynamicpanel
export loaddata

end # module
