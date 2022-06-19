function single_panel(datadir::String, extension::String=".lvm")

    datadir = abspath(datadir)
    fig = Figure(resolution = (1400, 1000), fontsize = 30)
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
        Label(fig, "Data", width = nothing), menu;
        tellheight = false, width = 300, height = 50
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
                x, y, name = loadfile(datadir, file, extension)

                if !(name in plotnames[])

                    xs.val = x
                    ys[] = y
                    autolimits!(ax)
                    ax.title = name

                    push!(xdata, x)
                    push!(ydata, y)
                    plotnames[] = push!(plotnames[], name)
                end
            end
        end
    end
end

function double_panel(datadir::String, extension::String=".lvm")

    datadir = abspath(datadir)
    fig = Figure(resolution = (2200, 1000), fontsize = 30)
    sc = display(fig)

    inspector = DataInspector(fig,
                    indicator_color = :deepskyblue, 
                    indicator_linewidth = 1.5,
                    text_align = (:left, :bottom)
                    )

    xdata = [rand(10)]
    ydata = [rand(10)]
    xslive = Observable(xdata[1])
    yslive = Observable(ydata[1])

    xs = Observable(xdata[1])
    ys = Observable(ydata[1])
    plotnames = Observable(["nothing"])
    plotname = Observable(plotnames[][1])

    menu = Menu(fig, options = plotnames)
    menu.i_selected = 1

    fig[1, 1] = vgrid!(
        Label(fig, "Select Data", width = nothing), menu;
        tellheight = false, width = 300, height = 50
        )

    ax = Axis(fig[1, 2], title = plotnames[][1])
    line = lines!(ax, xs, ys)

    axlive = Axis(fig[1, 3], title = plotname)
    line = lines!(axlive, xslive, yslive, color = :firebrick4)
    livetext = text!(axlive, "• Live",
                    textsize = 40,
                    color = :red,
                    space = :relative, 
                    align = (:left, :bottom))

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
                x, y, name = loadfile(datadir, file, extension)

                if !(name in plotnames[])

                    xslive.val = x
                    yslive[] = y
                    autolimits!(axlive)
                    axlive.title = name

                    push!(xdata, x)
                    push!(ydata, y)
                    plotnames[] = push!(plotnames[], name)
                end
            end
        end
    end
end

function panel(datadir::String, extension::String=".lvm")

    fig = Figure(resolution = (2000, 2000), fontsize = 40)
    sc = display(fig)

    inspector = DataInspector(fig,
                    indicator_color = :deepskyblue, 
                    indicator_linewidth = 3,
                    textsize = 30,
                    )

    fig[1:4, 1:2] = grid = GridLayout()
    
    xdata = [rand(10)]
    ydata = [rand(10)]
    # xs = Observable(xdata[1])
    # ys = Observable(ydata[1])
    plotnames = Observable(["nothing"])
    plotname = Observable(plotnames[][1])

    menus = [Menu(grid[row, col], options = plotnames, tellwidth = false, width = 500) for row in [1, 3], col = 1:2]
    axs = [Axis(grid[row, col]) for row in [2, 4], col = 1:2]
    xs = [Observable(xdata[1]) for i in 1:length(axs)]
    ys = [Observable(ydata[1]) for i in 1:length(axs)]

    # line = lines!(axs[1], xs[1], ys[1])

    for (m, menu) in enumerate(menus)
        menu.i_selected = 1
        lines!(axs[m], xs[m], ys[m])

        on(menu.selection) do s
            
            i = to_value(menu.i_selected)
            xs[m].val = xdata[i]
            ys[m][] = ydata[i]
            autolimits!(axs[m])
            axs[m].title = plotnames[][i]
        end
    end

    iswatching = Observable(true)
    while true
        while iswatching[]
            (file, event) = watch_folder(datadir)
            
            if endswith(file, extension)
                println("New file: ", file)
                x, y, name = loadfile(datadir, file, extension)

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

