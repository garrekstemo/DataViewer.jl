# All data reading and loading functions must take a single argument,
# the path of the raw data file, and must output... (still deciding the output). 

function get_filename(filepath::String)
    return chop(splitdir(filepath)[end], tail = 4)
end

"""
    load_test_data(filepath)

Use this function to test with test data 
in the testdata directory in this package.
"""
function load_test_data(filepath::String)

    loaded = DataFrame(CSV.File(filepath))
    filename = chop(splitdir(filepath)[end], tail = 4)
    return loaded[!, 1], loaded[!, 2], "x", "y", filename, loaded
end

"""
    load_mir(filepath)

Load data for MIR experiments using LVM.jl (:MIR project symbol)
and apply appropriate axis labels and plot title.
"""
function load_mir(filepath)
    filename = get_filename(filepath)

    xlabel = ""
    ylabel = "Transmitted signal"
    diff_ylabel = "Differential signal (pump on − pump off)"
    xdata = []
    ydata = []
    df = DataFrame()
    newdf = DataFrame()

    try
        df = readlvm(filepath)
    catch
        println("No data in file: ", filename)
        return nothing, filename
    end
    colnames = propertynames(df)

    if :wavelength in colnames
        xdata = df.wavelength
        xlabel = "Wavelength (nm)"
        newdf.wavelength = df.wavelength
    elseif :time in colnames
        xdata = df.time
        xlabel = "Pump delay (fs)"
        newdf.time = df.time
    else
        xdata = range(1, length = length(df[!, 1]))
        newdf.x = xdata
    end

    if :signal in colnames
        ydata = df.signal
        newdf.signal = df.signal
    else
        for name in colnames
            if occursin("CH0_", String(name))
                ydata = df[!, name]
                newdf.signal = df[!, name]
            end
        end
    end

    if :diff in colnames
        ydata = df.diff
        ylabel = diff_ylabel
        newdf.diff = df.diff
    end

    if :on in colnames
        newdf.on = df.on
    end
    if :off in colnames
        newdf.off = df.off
    end
    
    return xdata, ydata, xlabel, ylabel, filename, newdf
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

function load_wavelengths(filepath)
    wavelengths = readdlm(filepath, skipstart=1)[:, 1]
    return wavelengths
end