function loaddata(rawdf::DataFrame, file::String)

    xlabel = ""
    ylabel = ""
    xdata = []
    ydata = []

    colnames = propertynames(rawdf)
    df = DataFrame()

    if :wavelength in colnames
        xdata = rawdf.wavelength
        xlabel = "Wavelength (nm)"
    elseif :time in colnames
        xdata = rawdf.time ./ -1000
        xlabel = "Time (ps)"
    else
        xdata = range(1, length = length(rawdf[!, 1]))
    end

    if :signal in colnames
        ydata = rawdf.signal
        ylabel = "Signal (arb.)"
    else
        ydata = rawdf[!, 1]
        ylabel = String(propertynames(rawdf)[1])
    end
    if :ΔA in colnames
        ydata = rawdf.ΔA
        ylabel = "ΔA (arb.)"
    end

    filename = chop(file, tail = 4)
    return xdata, ydata, xlabel, ylabel, filename
end

function loaddata(rawdf::DataFrame, file::String; proj::Symbol = :test)

    colnames = propertynames(rawdf)
    filename = chop(file, tail = 4)
    return rawdf[!, 1], rawdf[!, 2], String(colnames[1]), String(colnames[2]), filename
end