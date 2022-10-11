function load_test_data(file::String)

    loaded = DataFrame(CSV.File(file))

    return loaded, title
end

function loaddata(filepath)

    xlabel = ""
    ylabel = ""
    xdata = []
    ydata = []

    df = DataFrame(readlvm(filepath, :MIR))
    colnames = propertynames(df)
    println(colnames)

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
        ylabel = "ΔA (arb.)"
    end

    filename = chop(file, tail = 4)
    
    return xdata, ydata, xlabel, ylabel, filename
end