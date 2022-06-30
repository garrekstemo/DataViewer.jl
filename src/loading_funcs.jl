# struct ExperimentHeaders{V <: AbstractVector{<:Symbol}}
#     headernames::V
# end

# const experimentheaders = Dict{Symbol, ExperimentHeaders}()

# function loadheadernames(experiment, headernames)
#     haskey(experimentheaders, experiment) && println("$experiment overwritten")
#     experimentheaders[experiment] = DataStream.ExperimentHeaders(headernames)
#     return experimentheaders[experiment]
# end



function loaddata(dir::String, file::String, extension::String=".lvm")

    
    if extension == ".lvm"
        rawdf = DataFrame(LVM.read(dir * file))
        colnames = propertynames(rawdf)
        df = DataFrame()

        if :wavelength in colnames
            df.wavelength = rawdf.wavelength
        elseif :time in colnames
            df.time = rawdf.time ./ -1000
        else
            df.X = range(1, length = length(rawdf[!, 1]))
        end

        if :diffsignal in colnames
            df.diffsignal = rawdf.diffsignal
        elseif :signal in colnames
            df.signal = rawdf.signal
        end

    else
        df = DataFrame(CSV.File(dir * file))
    end

    filename = chop(file, tail = length(extension))

    return df[!, 1], df[!, 2], filename
end