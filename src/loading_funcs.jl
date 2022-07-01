function loaddata(rawdf::DataFrame, file::String)

    xlabel = ""
    ylabel = ""

    colnames = propertynames(rawdf)
    df = DataFrame()

    if :wavelength in colnames
        df.wavelength = rawdf.wavelength
        xlabel = "Wavelength (nm)"
    elseif :time in colnames
        df.time = rawdf.time ./ -1000
        xlabel = "Time (ps)"
    else
        df.X = range(1, length = length(rawdf[!, 1]))
    end

    if :diffsignal in colnames
        df.diffsignal = rawdf.diffsignal
        ylabel = "ΔA (arb.)"
    elseif :signal in colnames
        df.signal = rawdf.signal
        ylabel = "Signal (arb.)"
    else
        df.Y = rawdf[!, 1]
    end

    filename = chop(file, tail = 4)
    return df[!, 1], df[!, 2], filename, xlabel, ylabel
end