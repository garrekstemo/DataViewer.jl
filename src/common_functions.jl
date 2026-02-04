# Axis labels - centralized to avoid inconsistencies
const AXIS_LABELS = (
    # X-axis (time)
    time_ps = "Time (ps)",
    time_fs = "Time (fs)",
    pump_delay_ps = "Pump delay (ps)",
    pump_delay_fs = "Pump delay (fs)",
    # X-axis (spectral)
    wavelength = "Wavelength (nm)",
    wavenumber = "Wavenumber (cm⁻¹)",
    # Y-axis
    diff = "−ΔT",
    transmission = "Transmission",
    intensity = "Intensity (Arb.)",
    signal = "Signal",
)

# Normalize directory paths so "output/" and "output" map to the same key.
_normdir(dir::AbstractString) = String(rstrip(abspath(dir), ['/', '\\']))

# Registry mapping monitored directories to their seen_files sets.
# Lets cleanup! reset the watcher without needing a handle from live_plot.
const _watcher_registry = Dict{String, Set{String}}()

"""
    cleanup!(dir)

Delete all files in `dir` and reset the file watcher history so
new files copied in will be detected again.
"""
function cleanup!(dir::AbstractString)
    dir = _normdir(dir)
    if !isdir(dir)
        println("Directory does not exist: $dir")
        return
    end

    n = 0
    for f in readdir(dir; join=true)
        if isfile(f)
            rm(f)
            n += 1
        end
    end

    if haskey(_watcher_registry, dir)
        empty!(_watcher_registry[dir])
    end

    println("Removed $n file(s) from $dir — watcher history cleared")
end

function make_savefig(x, y, title, xlabel, ylabel)
    fig = Figure()
    ax = Axis(fig[1, 1], title = title, 
            xlabel = xlabel,
            ylabel = ylabel,
            xticks = LinearTicks(10))
    lines!(ax, x, y)
    return fig
end