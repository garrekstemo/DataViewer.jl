function load_test_data(file::String)

    loaded = Dict()

    load = CSV.File(file)


    return load
end

function loaddata(rawdf::DataFrame, file::String; test = false)

    xlabel = ""
    ylabel = ""
    xdata = []
    ydata = []

    colnames = propertynames(rawdf)
    df = DataFrame()

    if test == true
        return rawdf[!, 1], rawdf[!, 2], String(colnames[1]), String(colnames[2]), filename
    end

    if :wavelength in colnames
        xdata = rawdf.wavelength
        xlabel = "Wavelength (nm)"
    elseif :time in colnames
        xdata = rawdf.time
        xlabel = "Time (fs)"
    else
        xdata = range(1, length = length(rawdf[!, 1]))
    end

    if :signal in colnames
        ydata = rawdf.signal
        ylabel = "Signal (arb.)"
    else
        for name in propertynames(rawdf)
            if occursin("CH0_", String(name))
                ydata = rawdf[!, name]
                ylabel = String(name)
            end
        end
    end

    if :ΔA in colnames
        ydata = rawdf.ΔA
        ylabel = "ΔA (arb.)"
    end

    filename = chop(file, tail = 4)
    
    return xdata, ydata, xlabel, ylabel, filename
end