function dynamicpanel(datadir::String, load_function::Function, file_ext::String;
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
    dataframe = Observable(DataFrame())

    sc = display(fig)
    DataInspector(fig)

    figbutton = Button(fig, label = "New Figure")
    fig[1, 1] = vgrid!(
        figbutton;
        tellheight = false, width = 130
        )
    
    axlive = Axis(fig[1, 2][1, 1], xticks = LinearTicks(7), yticks = LinearTicks(5))
    line = lines!(axlive, xslive, yslive, color = :firebrick4, linewidth = 1.0)
    livetext = text!(axlive, " • Live", color = :red, space = :relative, align = (:left, :bottom))


    # Button Actions

    on(figbutton.clicks) do _
        newfig = satellite_panel(dataframe)
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


function satellite_panel(df::DataFrame)

    fig = Figure()
    DataInspector(fig)

    menu_options = Observable(propertynames(df))

    menu = Menu(fig, options = menu_options, width = 180, tellwidth = true)

    x = Observable(df[!, 1])
    y = Observable(df[!, 2])
    # savebutton = Button(fig, label = "Save Figure")
    
    fig[1, 1] = vgrid!(
        menu;
        tellheight = false
        )

    ax = Axis(fig[1, 2], xticks = LinearTicks(7), yticks = LinearTicks(5))

    # on(savebutton.clicks) do _
    #     save_folder = "./plots/"
    #     if !isdir(save_folder)
    #         mkdir(save_folder)
    #     end
    #     plotname = "$(to_value(menu.selection))"

    #     save_path = abspath(save_folder * plotname * "_plot.png")
    #     savefig = make_savefig(newx, newy, plotname)

    #     save(save_path, savefig)
    #     println("Saved figure to ", save_path)
    # end


    on(menu.selection) do _
        i = to_value(menu.i_selected)

        # x.val = df[]
        y[] = df[!, i]

        # ax.title = menu_options[][i]
        # ax.xlabel = xlabels[][i]
        # ax.ylabel = ylabels[][i]
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
