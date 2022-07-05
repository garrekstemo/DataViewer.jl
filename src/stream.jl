function dynamicpanel(datadir::String; proj::Symbol=:MIR, ext::String=".lvm")
    datadir = abspath(datadir)

    fig = Figure(resolution = (800, 500))
    sc = display(fig)

    inspector = DataInspector(fig,
        indicator_color = :blue, 
        indicator_linewidth = 0.5,
        text_align = (:left, :bottom)
        )

    xdata, ydata = [rand(1)], [rand(1)]
    xslive, yslive = Observable(xdata[1]), Observable(ydata[1])
    
    xlabels, ylabels = Observable([""]), Observable([""])
    plotnames = Observable(["no options"])
    
    dfs = []

    lw = 1.0

    axbutton = Button(fig, label = "Add Axis")
    figbutton = Button(fig, label = "New Figure")
    
    fig[1, 1] = vgrid!(
        axbutton,
        figbutton;
        tellheight = false, width = 190
        )
    
    axlive = Axis(fig[1, 2][1, 1], xticks = LinearTicks(7), yticks = LinearTicks(5))
    livetext = text!(axlive, " • Live", color = :red, space = :relative, align = (:left, :bottom))

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
        if col == 3
            row += 2
            col = 1
        end
    end

    on(figbutton.clicks) do _
        newfig = satellite_panel(plotnames, xlabels, ylabels, xdata, ydata, dfs)
        display(GLMakie.Screen(), newfig)
    end

    # Watch for new data
    # ------------------

    while true
        (file, event) = watch_folder(datadir)
        
        if endswith(file, ext)

            if findfirst('\\', file) == 1
                file = file[2:end]
            end
            println("New file: ", file)

            if ext == ".lvm"
                rawdf = DataFrame(readlvm(datadir * file, proj))

                if size(rawdf) == (0, 0)
                    println("I read that file before it could finish writing. Trying again...")
                    sleep(1)
                    rawdf = DataFrame(readlvm(datadir * file, proj))
                end
                push!(dfs, rawdf)

            else
                rawdf = DataFrame(CSV.File(datadir * file))
            end


            if proj == :test
                x, y, xlabel, ylabel, ptitle = loaddata(rawdf, file, proj = :test)
            else
                x, y, xlabel, ylabel, ptitle = loaddata(rawdf, file)
            end

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


function satellite_panel(menu_options, xlabels, ylabels, xs, ys, dfs)

    fig = Figure(resolution = (800, 500))

    inspector = DataInspector(fig,
                    indicator_color = :deepskyblue, 
                    indicator_linewidth = 1.5,
                    text_align = (:left, :bottom)
                    )

    menu = Menu(fig, options = menu_options, width = 200, tellwidth = true)
    menu.i_selected = 1

    toggle1 = Button(fig, label = "CH0 ON")
    toggle2 = Button(fig, label = "CH0 OFF")

    vis1 = Observable(true)
    vis2 = Observable(false)

    savebutton = Button(fig, label = "Save Figure")
    
    fig[1, 1] = vgrid!(
        menu,
        toggle1,
        toggle2,
        savebutton;
        tellheight = false, width = 190
        # tellheight = false, width = 250
        )

    lw = 1.0

    ax = Axis(fig[1, 2], xticks = LinearTicks(7), yticks = LinearTicks(5))
    
    newx, newy = Observable(xs[1]), Observable(ys[1])
    df = Observable(dfs[1])

    l1 = lines!(ax, newx, newy, linewidth = lw)


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

    on(toggle1.clicks) do _
        vis1[] = !(vis1.val)
    end
    on(toggle2.clicks) do _
        vis2[] = !(vis2.val)
    end

    on(menu.selection) do _
        i = to_value(menu.i_selected)

        
        newx.val = xs[i]
        newy[] = ys[i]
        df[] = dfs[i-1]
        if :ΔA in propertynames(df.val)

            ax2 = Axis(fig[1, 2], ylabel = "CH0 ON/OFF", yaxisposition = :right)
    
            l2 = lines!(ax2, newx.val, df[].on, linewidth = lw, color = :orange, visible = vis1)
            l3 = lines!(ax2, newx.val, df[].off, linewidth = lw, color = :orangered, visible = vis2)

            hidespines!(ax2)
            hidexdecorations!(ax2)
            hideydecorations!(ax2, ticks = false, ticklabels = false, label = false)
        end
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
    lines!(ax, x, y)
    return fig
end
