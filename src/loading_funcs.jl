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

    df = DataFrame(readlvm(filepath, :MIR))
    colnames = propertynames(df)

    if :wavelength in colnames
        xdata = df.wavelength
        xlabel = "Wavelength (nm)"
    elseif :time in colnames
        xdata = df.time
        xlabel = "Time (fs)"
    else
        xdata = range(1, length = length(df[!, 1]))
    end

    if :signal in colnames
        ydata = df.signal
        ylabel = "Signal (arb.)"
    else
        for name in colnames
            if occursin("CH0_", String(name))
                ydata = df[!, name]
                ylabel = String(name)
            end
        end
    end

    if :ΔA in colnames
        ydata = df.ΔA
        ylabel = "Δ (arb.)"
    end

    filename = chop(splitdir(filepath)[end], tail = 4)
    
    return xdata, ydata, xlabel, ylabel, filename
end