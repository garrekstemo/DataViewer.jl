function dynamicpanel(datadir::String, extension::String=".lvm")
    datadir = abspath(datadir)

    fig = Figure(resolution = (1000, 400))
    sc = display(fig)

    inspector = DataInspector(fig,
        indicator_color = :blue, 
        indicator_linewidth = 0.5,
        text_align = (:left, :bottom)
        )

    xdata = [rand(1)]
    ydata = [rand(1)]

    xslive = Observable(xdata[1])
    yslive = Observable(ydata[1])
    xs = [Observable(xdata[1])]
    ys = [Observable(ydata[1])]
    plotnames = Observable(["no options"])

    lw = Observable(1.0)

    axbutton = Button(fig, label = "Add Axis")
    figbutton = Button(fig, label = "New Figure")
    
    fig[1, 1] = vgrid!(
        axbutton,
        figbutton,
        Label(fig, "Linewidth", justification = :center);
        tellheight = false, width = 100
        )

    fig[1, 1][4, 1] = lwbuttongrid = GridLayout(tellwidth = false)
    lwupbutton = Button(lwbuttongrid[1, 1], label = "⬆")
    lwdownbutton = Button(lwbuttongrid[1, 2], label = "⬇")
    
    axlive = Axis(fig[1, 2][1, 1], xticks = LinearTicks(7), yticks = LinearTicks(5))
    livetext = text!(axlive, " • Live",
                    # textsize = 40,
                    color = :red,
                    space = :relative, 
                    align = (:left, :bottom)
                    )

    # Button Actions
    # -------------- #

    menus = []
    col = 2
    row = 1
    on(axbutton.clicks) do _
        ax = Axis(fig[1, 2][row, col], xticks = LinearTicks(7), yticks = LinearTicks(5), tellheight = false)

        newmenu = Menu(fig[1, 2][row+1, col], options = plotnames, tellwidth=false)
        newmenu.i_selected = 1
        push!(menus, newmenu)

        newx, newy = Observable(xdata[1]), Observable(ydata[1])
        l = lines!(ax, newx, newy, linewidth = lw)

        on(newmenu.selection) do _
            i = to_value(newmenu.i_selected)

            newx.val = xdata[i]
            newy[] = ydata[i]
            ax.title = plotnames[][i]
            autolimits!(ax)
        end

        col += 1
        if col == 4
            row += 2
            col = 1
        end
    end

    on(lwupbutton.clicks) do _
        lw[] = lw[] + 0.5
    end
    on(lwdownbutton.clicks) do _
        lw[] = lw[] - 0.5
    end

    on(figbutton.clicks) do _
        newfig = satellite_panel(plotnames, xdata, ydata)
        display(GLMakie.Screen(), newfig)
    end

    # Watch for new data
    # ------------------

    while true
        (file, event) = watch_folder(datadir)
        sleep(0.01)
        
        if endswith(file, extension)
            println("New file: ", file)
            x, y, name = loaddata(datadir, file, extension)

            if !(name in plotnames[])

                xslive.val = x
                yslive[] = y

                if plotnames[][1] == "no options"
                    line = lines!(axlive, xslive, yslive, color = :firebrick4, linewidth = lw)
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


function satellite_panel(menu_options, xs, ys)
    fig = Figure(resolution = (800, 600))

    inspector = DataInspector(fig,
                    indicator_color = :deepskyblue, 
                    indicator_linewidth = 1.5,
                    text_align = (:left, :bottom)
                    )

    menu = Menu(fig, options = menu_options, width = 200, tellwidth = true)
    menu.i_selected = 1

    savebutton = Button(fig, label = "Save Figure")

    lw = Observable(1)
    
    fig[1, 1] = vgrid!(
        menu,
        savebutton,
        Label(fig, "Linewidth", justification = :center);
        tellheight = false, width = 200
        )
    fig[1, 1][4, 1] = lwbuttongrid = GridLayout(tellwidth = false)
    
    lwupbutton = Button(lwbuttongrid[1, 1], label = "⬆")
    lwdownbutton = Button(lwbuttongrid[1, 2], label = "⬇")


    ax = Axis(fig[1, 2], xticks = LinearTicks(7), yticks = LinearTicks(5))
    newx, newy = Observable(xs[1]), Observable(ys[1])
    l = lines!(ax, newx, newy, linewidth = lw)

    on(lwupbutton.clicks) do _
        lw[] = lw[] + 0.5
    end
    on(lwdownbutton.clicks) do _
        lw[] = lw[] - 0.5
    end

    on(savebutton.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end
        plotname = "$(to_value(menu.selection))"

        save_path = abspath(save_folder * plotname * "_plot.png")
        savefig = make_savefig(newx, newy, plotname)

        save(save_path, savefig)
        println("Saved figure to ", save_path)
    end

    on(menu.selection) do _
        i = to_value(menu.i_selected)

        newx.val = xs[i]
        newy[] = ys[i]
        ax.title = menu_options[][i]
        autolimits!(ax)
    end

    fig
end

function make_savefig(x, y, title)
    fig = Figure()
    ax = Axis(fig[1, 1], title = title, xticks = LinearTicks(10))
    lines!(x, y)
    return fig
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
                x, y, name = loaddata(datadir, file, extension)

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
