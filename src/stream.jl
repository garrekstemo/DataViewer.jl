function dynamicpanel(datadir::String, extension::String=".lvm")
    datadir = abspath(datadir)

    fig = Figure()
    sc = display(fig)

    # inspector = DataInspector(fig,
    #     indicator_color = :deepskyblue, 
    #     indicator_linewidth = 1.5,
    #     text_align = (:left, :bottom)
    #     )

    xdata = [rand(1)]
    ydata = [rand(1)]
    xs = Observable(xdata[1])
    ys = Observable(ydata[1])
    xslive = Observable(xdata[1])
    yslive = Observable(ydata[1])

    xs = [Observable(xdata[1])]
    ys = [Observable(ydata[1])]
    plotnames = Observable(["no options"])

    axbutton = Button(fig, label = "Add Axis")

    fig[1, 1] = vgrid!(
        axbutton;
        tellheight = false, width = 300, height = 50
        )

    axlive = Axis(fig[1, 2], xticks = LinearTicks(7), yticks = LinearTicks(5))
    livetext = text!(axlive, " • Live",
                    # textsize = 40,
                    color = :red,
                    space = :relative, 
                    align = (:left, :bottom)
                    )

    axs = []
    plots = []
    menus = []

    col = 3
    row = 1
    on(axbutton.clicks) do b
        ax = Axis(fig[row, col], xticks = LinearTicks(7), yticks = LinearTicks(5))
        push!(axs, ax)

        newmenu = Menu(fig[row+1, col], options = plotnames, tellwidth=false)
        newmenu.i_selected = 1
        push!(menus, newmenu)

        newx, newy = Observable(xdata[1]), Observable(ydata[1])
        l = lines!(ax, newx, newy)
        push!(plots, l)

        on(newmenu.selection) do s
            i = to_value(newmenu.i_selected)

            newx.val = xdata[i]
            newy[] = ydata[i]
            ax.title = plotnames[][i]
            autolimits!(ax)
        end

        col += 1
        if col == 5
            row += 2
            col = 2
        end
    end

    while true
        (file, event) = watch_folder(datadir)
        sleep(0.003)
        
        if endswith(file, extension)
            println("New file: ", file)
            x, y, name = loadfile(datadir, file, extension)

            if !(name in plotnames[])

                xslive.val = x
                yslive[] = y

                if plotnames[][1] == "no options"
                    line = lines!(axlive, xslive, yslive, color = :firebrick4)
                end

                autolimits!(axlive)
                axlive.title = name

                push!(xdata, x)
                push!(ydata, y)
                plotnames[] = push!(plotnames[], name)
            end
        end
    end

end


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
