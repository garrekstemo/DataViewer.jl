"""
    livepanel(datadir::String, load_function::Function, file_ext::String; waittime = 0.1, theme = nothing)

A panel with a plot that updates when a new data file is found
in the given directory. Satellite panels can be opened via buttons.
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
    satellite_panel(df::DataFrame, title)

A satellite panel that appears upon clicking a button on the live panel.
Not a user-facing function.
"""
function satellite_panel(df::DataFrame, title)

    fig = Figure()
    DataInspector(fig)

    colnames = names(df)
    println(colnames)
    # Set x units
    startunits = ""
    wavelen = "Wavelength (nm)"
    wavenum = "Wavenumber (cm⁻¹)"
    fs = "Pump delay (fs)"
    ps = "Pump delay (ps)"
    
    if "wavelength" in lowercase.(colnames)
        startunits = "Wavelength (nm)"
    elseif "time" in lowercase.(colnames)
        startunits = "Pump delay (fs)"
    else
        startunits = "x"
    end

    # Observables and widgets

    menu_options = Observable(["nonlinear", "linear"])
    x = Observable(df[!, 1])
    y = Observable(df[!, 2])

    menu = Menu(fig, options = menu_options, width = 150, tellwidth = true)
    savebutton = Button(fig, label = "Save as png")
    xunits_button = Button(fig, label = startunits)
    
    # Draw figure

    fig[1, 1] = vgrid!(
        Label(fig, "Choose data", justification = :center, width=nothing),
        menu,
        savebutton,
        Label(fig, "Change x units", justification = :center, width=nothing),
        xunits_button;
        tellheight = false
        )

    ax = Axis(fig[1, 2],
        title = title,
        xlabel = startunits,
        ylabel = colnames[2], 
        xticks = LinearTicks(7),
        yticks = LinearTicks(5)
        )
    lines!(ax, x, y)


    # Button & Menu actions

    on(xunits_button.clicks) do _
        if to_value(ax.xlabel) == wavelen
            x[] = 10^7 ./ x[]
            ax.xlabel = wavenum
            xunits_button.label = wavenum
        elseif to_value(ax.xlabel) == wavenum
            x[] = 10^7 ./ x[]
            ax.xlabel = wavelen
            xunits_button.label = wavelen
        elseif to_value(ax.xlabel) == fs
            x[] = x[] ./ 1000
            ax.xlabel = ps
            xunits_button.label = ps
        elseif to_value(ax.xlabel) == ps
            x[] = x[] .* 1000
            ax.xlabel = fs
            xunits_button.label = fs
        end
        autolimits!(ax)
    end

    on(savebutton.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end

        plotname = title * "_$(to_value(menu.selection))"
        save_path = abspath(joinpath(save_folder, plotname * ".png"))
        savefig = make_savefig(x, y, plotname, to_value(ax.xlabel), to_value(ax.ylabel))
        save(save_path, savefig)
        println("Saved figure to ", save_path)
    end

    on(menu.selection) do selected

        if selected == "nonlinear"
            y[] = df.signal
            ax.ylabel = "ΔA (arb.)"
        elseif selected == "linear"
            y[] = df.off
            ax.ylabel = "pump on/off intensity (arb.)"
        end
        autolimits!(ax)
    end

    return fig
end

function make_savefig(x, y, title, xlabel, ylabel)
    fig = Figure()
    ax = Axis(fig[1, 1], title = title, 
            xlabel = xlabel,
            ylabel = ylabel,
            xticks = LinearTicks(10))
    lines!(ax, x, y)
    return fig
end
