"""
    dynamicpanel()

A panel with a plot that updates when a new data file is found
in the given directory.
"""
function livepanel(datadir::String, load_function::Function, file_ext::String;
                        waittime = 0.1,
                        theme = nothing
                        )

    datadir = abspath(datadir)

    if theme !== nothing
        set_theme!(theme)
    end

    fig = Figure()

    xdata, ydata = [rand(1)], [rand(1)]
    xslive, yslive = Observable(xdata[1]), Observable(ydata[1])
    xlabels, ylabels = Observable([""]), Observable([""])
    plotnames = Observable(["no options"])
    dataframe = Observable(DataFrame(A = rand(1), B = rand(1)))

    sc = display(fig)
    DataInspector(fig)

    figbutton = Button(fig, label = "New Figure")
    fig[2, 1] = vgrid!(
        figbutton;
        tellwidth = false,
        )
    
    axlive = Axis(fig[1,1][1, 1], xticks = LinearTicks(7), yticks = LinearTicks(5))
    line = lines!(axlive, xslive, yslive, color = :firebrick4, linewidth = 1.0)
    livetext = text!(axlive, " • Live", color = :red, space = :relative, align = (:left, :bottom))


    # Button Actions

    on(figbutton.clicks) do _
        newfig = satellite_panel(to_value(dataframe), to_value(plotnames)[1])
        display(GLMakie.Screen(), newfig)
    end


    # Watch for new data
    while true
        (file, event) = watch_folder(datadir)
        sleep(waittime)
        
        if endswith(file, file_ext)

            if findfirst('\\', file) == 1
                file = file[2:end]
            end
            println("New file: ", file)

            x, y, xlabel, ylabel, ptitle, df = load_function(joinpath(datadir, file))

            if !(ptitle in plotnames[])

                xslive.val = x
                yslive[] = y
                dataframe[] = df

                autolimits!(axlive)
                axlive.title = ptitle
                axlive.xlabel = xlabel
                axlive.ylabel = ylabel

                pushfirst!(xdata, x)
                pushfirst!(ydata, y)
                pushfirst!(xlabels[], xlabel)
                pushfirst!(ylabels[], ylabel)
                plotnames[] = pushfirst!(plotnames[], ptitle)
            end
        end
    end

end

"""
    satellite_panel(df::DataFrame)

A satellite panel that appears upon clicking a button on the live panel.
Not a user-facing function.
"""
function satellite_panel(df::DataFrame, title)

    fig = Figure()
    DataInspector(fig)

    colnames = names(df)
    menu_options = Observable(colnames)
    x = Observable(df[!, 1])
    y = Observable(df[!, 2])

    menu = Menu(fig, options = menu_options, width = 150, tellwidth = true)
    savebutton = Button(fig, label = "Save as png")
    
    fig[1, 1] = vgrid!(
        Label(fig, "Choose y-axis", width=nothing),
        menu,
        savebutton;
        tellheight = false
        )

    ax = Axis(fig[1, 2], xlabel = colnames[1], ylabel = colnames[2], 
                         xticks = LinearTicks(7), yticks = LinearTicks(5))

    lines!(ax, x, y)
    ax.title = title

    on(savebutton.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end
        plotname = title * "_$(to_value(menu.selection)).png"

        save_path = joinpath(save_folder, plotname)
        savefig = make_savefig(x, y, plotname)

        save(save_path, savefig)
        println("Saved figure to ", save_path)
    end


    on(menu.selection) do _
        i = to_value(menu.i_selected)
        y[] = df[!, i]
        ax.ylabel = colnames[i]
        autolimits!(ax)
    end

    return fig
end

function make_savefig(x, y, title)
    fig = Figure()
    ax = Axis(fig[1, 1], title = title, xticks = LinearTicks(10))
    lines!(ax, x, y)
    return fig
end
