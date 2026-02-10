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
    delta_a = "ΔA",
    # Pixel axes (CCD)
    pixel_row = "Row (pixel)",
    pixel_col = "Column (pixel)",
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

"""
    _is_spectral_data(data, xlabel)

Check whether loaded data represents a spectral measurement (wavelength/wavenumber)
rather than kinetics (time). Uses PumpProbeData.axis_type when available,
falls back to xlabel string matching.
"""
function _is_spectral_data(data, xlabel)
    if data isa QPS.PumpProbeData
        return data.axis_type == QPS.wavelength_axis
    end
    return xlabel == AXIS_LABELS.wavelength || xlabel == AXIS_LABELS.wavenumber
end

const _UNIT_CONVERSIONS = Dict(
    AXIS_LABELS.wavelength    => (x -> 10^7 ./ x, AXIS_LABELS.wavenumber),
    AXIS_LABELS.wavenumber    => (x -> 10^7 ./ x, AXIS_LABELS.wavelength),
    AXIS_LABELS.time_fs       => (x -> x ./ 1000, AXIS_LABELS.time_ps),
    AXIS_LABELS.pump_delay_fs => (x -> x ./ 1000, AXIS_LABELS.pump_delay_ps),
    AXIS_LABELS.time_ps       => (x -> x .* 1000, AXIS_LABELS.time_fs),
    AXIS_LABELS.pump_delay_ps => (x -> x .* 1000, AXIS_LABELS.pump_delay_fs),
)

function _extract_data(data)
    if data isa QPS.PumpProbeData
        return QPS.xaxis(data), data.diff[:, 1], true, data.on[:, 1], data.off[:, 1]
    elseif data isa NamedTuple
        return data.x, data.y, false, Float64[], Float64[]
    else
        error("Unsupported data type: $(typeof(data))")
    end
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

function make_savefig_heatmap(img, title;
        x=nothing, y=nothing,
        xlabel=AXIS_LABELS.pixel_col,
        ylabel=AXIS_LABELS.pixel_row,
        colormap=:RdBu,
        colorbar_label=AXIS_LABELS.delta_a)
    max_abs = maximum(abs, img)
    cr = max_abs > 0 ? (-max_abs, max_abs) : (-1.0, 1.0)
    fig = Figure()
    ax = Axis(fig[1, 1], title=title, xlabel=xlabel, ylabel=ylabel)
    if x !== nothing && y !== nothing
        hm = heatmap!(ax, x, y, img, colormap=colormap, colorrange=cr)
    else
        hm = heatmap!(ax, img, colormap=colormap, colorrange=cr)
    end
    Colorbar(fig[1, 2], hm, label=colorbar_label)
    return fig
end