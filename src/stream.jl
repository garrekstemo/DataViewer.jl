function dynamicpanel(datadir::String, experiment::Symbol=:MIR, extension::String=".lvm")
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

    xlabels = Observable([""])
    ylabels = Observable([""])
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
            ax.xlabel = xlabels[][i]
            ax.ylabel = ylabels[][i]
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
        newfig = satellite_panel(plotnames, xlabels, ylabels, xdata, ydata)
        display(GLMakie.Screen(), newfig)
    end

    # Watch for new data
    # ------------------

    while true
        (file, event) = watch_folder(datadir)
        
        if endswith(file, extension)
            if findfirst('\\', file) == 1
                file = file[2:end]
            end
            println("New file: ", file)

            if extension == ".lvm"
                rawdf = DataFrame(readlvm(datadir * file, experiment))
            else
                rawdf = DataFrame(CSV.File(datadir * file))
            end

            if size(rawdf) == (0, 0)
                println("I read that file before it could finish writing. Trying again...")
                sleep(1)
                rawdf = DataFrame(readlvm(datadir * file, experiment))
            end

            x, y, ptitle, xlabel, ylabel = loaddata(rawdf, file)

            if !(ptitle in plotnames[])

                xslive.val = x
                yslive[] = y

                if plotnames[][1] == "no options"
                    line = lines!(axlive, xslive, yslive, color = :firebrick4, linewidth = lw)
                end

                autolimits!(axlive)
                axlive.title = ptitle
                axlive.xlabel = xlabel
                axlive.ylabel = ylabel

                push!(xdata, x)
                push!(ydata, y)
                push!(xlabels[], xlabel)
                push!(ylabels[], ylabel)
                plotnames[] = push!(plotnames[], ptitle)
            end
        end
    end

end


function satellite_panel(menu_options, xlabels, ylabels, xs, ys)
    fig = Figure(resolution = (900, 600))

    inspector = DataInspector(fig,
                    indicator_color = :deepskyblue, 
                    indicator_linewidth = 1.5,
                    text_align = (:left, :bottom)
                    )

    menu = Menu(fig, options = menu_options, width = 175, tellwidth = true)
    menu.i_selected = 1

    savebutton = Button(fig, label = "Save Figure")

    lw = Observable(1.0)
    
    fig[1, 1] = vgrid!(
        menu,
        savebutton,
        Label(fig, "Linewidth", justification = :center);
        tellheight = false, width = 190
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
        ax.xlabel = xlabels[][i]
        ax.ylabel = ylabels[][i]
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
