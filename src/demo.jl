function loadfile(dir::String, file::String)

    df = DataFrame(CSV.File(dir * file))

    filename = chop(file, tail = length(".csv"))

    return df[!, 1], df[!, 2], filename
end

function run(datadir::String, extension)

    fig = Figure()
    sc = display(fig)

    inspector = DataInspector(fig,
                    indicator_color = :deepskyblue, 
                    indicator_linewidth = 1.5,
                    text_align = (:left, :bottom)
                    )

    xdata = [rand(10)]
    ydata = [rand(10)]
    xs = Observable(xdata[1])
    ys = Observable(ydata[1])
    plotnames = Observable(["nothing"])
    plotname = Observable(plotnames[][1])

    menu = Menu(fig, options = plotnames)
    menu.i_selected = 1

    fig[1, 1] = vgrid!(
        Label(fig, "Data", width = nothing), menu,
        Label(fig, "Plot 2", width = nothing), menu2;
        tellheight = false, width = 200, height = 50
        )
    
    ax = Axis(fig[1, 2], title = plotname)
    line = lines!(ax, xs, ys)


    on(menu.selection) do s

        i = to_value(menu.i_selected)
        xs.val = xdata[i]
        ys[] = ydata[i]
        autolimits!(ax)
        ax.title = plotnames[][i]
    end

    iswatching = Observable(true)
    while true
        while iswatching[]
            (file, event) = watch_folder(datadir)
            
            if endswith(file, extension)
                println("New file: ", file)
                x, y, name = loadfile(datadir, file)

                if !(name in plotnames[])

                    xs[1].val = x
                    ys[1][] = y
                    autolimits!(axs[1])
                    axs[1].title = name

                    push!(xdata, x)
                    push!(ydata, y)
                    plotnames[] = push!(plotnames[], name)
                end
            end
        end
    end
end


f 