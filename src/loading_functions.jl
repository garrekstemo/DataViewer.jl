# Data loading functions for QPSView
# Uses QPS.jl for LVM file loading

function get_filename(filepath::String)
    return chop(splitdir(filepath)[end], tail = 4)
end

"""
    load_test_data(filepath)

Load CSV test data for demos. Returns tuple compatible with live_plot.
Returns a simple NamedTuple instead of DataFrame for the data container.
"""
function load_test_data(filepath::String)
    # Read CSV without DataFrames - just get the raw data
    rows = CSV.File(filepath)
    x = [row[1] for row in rows]
    y = [row[2] for row in rows]
    filename = get_filename(filepath)

    # Return a NamedTuple as the data container (replaces DataFrame)
    data = (x=x, y=y)
    return x, y, "x", "y", filename, data
end

"""
    load_mir(filepath; channel=1)

Load MIR pump-probe data using QPS.jl.

Returns: (time, signal, xlabel, ylabel, filename, PumpProbeData)

The PumpProbeData struct contains:
- `time`: Time axis in ps
- `on`: Pump-on signal matrix (columns = channels)
- `off`: Pump-off signal matrix
- `diff`: Lock-in difference signal matrix
- `timestamp`: Acquisition timestamp
"""
function load_mir(filepath; channel::Int=1)
    filename = get_filename(filepath)

    try
        data = QPS.load_lvm(filepath)

        # Use difference signal (channel 1 = index 1)
        xdata = QPS.xaxis(data)
        ydata = data.diff[:, channel]

        # Auto-detect axis type (time vs wavelength)
        xlabel = QPS.xaxis_label(data)

        # Detect if this is pump-probe (has on/off data) or single beam
        has_pump_data = !all(iszero, data.on[:, channel]) || !all(iszero, data.off[:, channel])
        ylabel = has_pump_data ? AXIS_LABELS.diff : AXIS_LABELS.signal

        return xdata, ydata, xlabel, ylabel, filename, data
    catch e
        println("Error loading file $filename: ", e)
        return nothing, nothing, "", "", filename, nothing
    end
end

function load_image(filepath)
    filename = get_filename(filepath)
    try
        raw = readdlm(filepath, skipstart=1)
        return raw, filename
    catch
        println("No data in file: ", filename)
        return nothing, filename
    end
end

function load_axis_file(filepath)
    readdlm(filepath, skipstart=1)[:, 1]
end