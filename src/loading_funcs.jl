function loadfile(dir::String, file::String, extension::String=".lvm")

    if extension == ".lvm"
        rawdf = DataFrame(LVM.read(dir * file))
        colnames = propertynames(rawdf)
        df = DataFrame()

        if :Wavelength in colnames
            df.Wavelength = rawdf.Wavelength
        else
            df.X = range(1, length = length(rawdf[!, 1]))
        end

        if :DiffSignal in colnames
            df.DiffSignal = rawdf.DiffSignal
        elseif :Signal in colnames
            df.Signal = rawdf.Signal
        end

    elseif extension == ".csv"
        df = DataFrame(CSV.File(dir * file))
    end

    filename = chop(file, tail = length(extension))

    return df[!, 1], df[!, 2], filename
end