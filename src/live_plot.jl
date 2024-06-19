"""
    livepanel(datadir::String, load_function::Function, file_ext::String; waittime = 0.1, theme = nothing)

A panel with a plot that updates when a new data file is found
in the given directory. Satellite panels can be opened via buttons.
"""
function live_plot(
        datadir::String,
        load_function::Function=load_mir,
        file_ext::String=".lvm";
        waittime = 0.1,
    )
    datadir = abspath(datadir)

    fig = Figure()
    sc = display(fig)
    DataInspector(fig)

    x = Observable(rand(1))
    y = Observable(rand(1))
    dataframe = Observable(DataFrame(A = rand(1), B = rand(1)))

    ax = Axis(fig[1, 1][1, 1], xticks = LinearTicks(7), yticks = LinearTicks(5))
    line = lines!(x, y, color = :firebrick4, linewidth = 1.0)
    livetext = text!(" • Live", color = :red, space = :relative, align = (:left, :bottom))

    figbutton = Button(fig, label = "New Figure")
    fig[2, 1] = vgrid!(
        figbutton;
        tellwidth = false,
        )

    # Button Actions

    on(figbutton.clicks) do _
        newfig = satellite_panel(to_value(dataframe), ax.title)
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

            new_x, new_y, xlabel, ylabel, ptitle, df = load_function(joinpath(datadir, file))

            if new_x !== nothing && new_y !== nothing

                x.val = new_x
                y[] = new_y
                dataframe[] = df

                autolimits!(ax)
                ax.title = ptitle
                ax.xlabel = xlabel
                ax.ylabel = ylabel
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

    x = Observable(df[!, 1])
    y = Observable(df[!, 2])  # automatically plot difference data if it exists
    savebutton = Button(fig, label = "Save as png")
    xunits_button = Button(fig, label = "Change x units")
    
    # Draw figure

    fig[1, 1][1, 1] = vgrid!(
        savebutton,
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
    lineplots = [lines!(ax, x, y, color = :indigo, label = "ΔT", visible = true)]


    # Buttons and Interactivity

    if length(colnames) > 2
        transmission_button = Button(fig[2, 2][1, 1], label = "Transmission", tellwidth = false)
        difference_button = Button(fig[2, 2][1, 2], label = "ΔT", tellwidth = false)

        push!(lineplots, lines!(ax, x, -df.off, color = :deepskyblue3, label = "pump off", visible = false))
        push!(lineplots, lines!(ax, x, -df.on, color = :crimson, label = "pump on", visible = false))
        Legend(fig[1, 1][2, 1], ax)

        on(difference_button.clicks) do _
                lineplots[1].visible = true
                lineplots[2].visible = false
                lineplots[3].visible = false
                ax.ylabel = "ΔA (arb.)"
                autolimits!(ax)
        end
        on(transmission_button.clicks) do _
                lineplots[1].visible = false
                lineplots[2].visible = true
                lineplots[3].visible = true
                ax.ylabel = "Pump on/off intensity (arb.)"
                autolimits!(ax)
        end
    end

    on(xunits_button.clicks) do _
        if to_value(ax.xlabel) == wavelen
            x[] = 10^7 ./ x[]
            ax.xlabel = wavenum
        elseif to_value(ax.xlabel) == wavenum
            x[] = 10^7 ./ x[]
            ax.xlabel = wavelen
        elseif to_value(ax.xlabel) == fs
            x[] = x[] ./ 1000
            ax.xlabel = ps
        elseif to_value(ax.xlabel) == ps
            x[] = x[] .* 1000
            ax.xlabel = fs
        end
        autolimits!(ax)
    end

    on(savebutton.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end

        plotname = to_value(title)
        save_path = abspath(joinpath(save_folder, plotname * ".png"))
        # savefig = make_savefig(x, y, plotname, to_value(ax.xlabel), to_value(ax.ylabel))
        save(save_path, fig)
        println("Saved figure to ", save_path)
        fig
    end
    
    return fig
end

