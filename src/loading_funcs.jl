# All data reading and loading functions must take a single argument,
# the path of the raw data file, and must output... (still deciding the output). 

"""
    load_test_data(filepath)

Use this function to test with test data 
in the testdata directory in this package.
"""
function load_test_data(filepath::String)

    loaded = DataFrame(CSV.File(filepath))

    return loaded, title
end

"""
    load_mir(filepath)

Load data for MIR experiments using LVM.jl (:MIR project symbol)
and apply appropriate axis labels and plot title.
"""
function load_mir(filepath)

    xlabel = ""
    ylabel = ""
    xdata = []
    ydata = []

    df = readlvm(filepath)
    newdf = DataFrame()
    colnames = propertynames(df)

    if :wavelength in colnames
        xdata = df.wavelength
        xlabel = "Wavelength (nm)"
        newdf.wavelength = df.wavelength
    elseif :time in colnames
        xdata = df.time
        xlabel = "Time (fs)"
        newdf.time = df.time
    else
        xdata = range(1, length = length(df[!, 1]))
        newdf.x = xdata
    end

    if :signal in colnames
        ydata = df.signal
        ylabel = "Signal (arb.)"
        newdf.signal = df.signal
    else
        for name in colnames
            if occursin("CH0_", String(name))
                ydata = df[!, name]
                ylabel = String(name)
                newdf.signal = df[!, name]
            end
        end
    end

    if :diff in colnames
        ydata = df.diff
        ylabel = "ΔA (arb.)"
        newdf.diff = df.diff
    end

    if :on in colnames
        newdf.on = df.on
    end
    if :off in colnames
        newdf.off = df.off
    end

    filename = chop(splitdir(filepath)[end], tail = 4)
    
    return xdata, ydata, xlabel, ylabel, filename, newdf
end