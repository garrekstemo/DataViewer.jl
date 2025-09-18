"""
    setup_live_plot_gui()

Creates and configures the GUI components for live plotting.
Returns the figure, axis, and observables needed for live updates.
"""
function setup_live_plot_gui()
    GLMakie.activate!()
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
    stopbutton = Button(fig, label = "Stop Monitoring")
    fig[2, 1] = hgrid!(
        figbutton,
        stopbutton;
        tellwidth = false,
        )

    # Create stop signal for graceful shutdown
    stop_signal = Ref(false)

    # Button Actions
    on(figbutton.clicks) do _
        newfig = satellite_panel(to_value(dataframe), to_value(ax.xlabel), to_value(ax.ylabel), to_value(ax.title))
        display(GLMakie.Screen(), newfig)
    end

    on(stopbutton.clicks) do _
        stop_signal[] = true
        println("Stopping file monitoring...")
    end

    return fig, ax, x, y, dataframe, stop_signal
end

"""
    update_plot_data!(x, y, dataframe, ax, new_x, new_y, xlabel, ylabel, ptitle, df)

Updates the plot observables and axis labels with new data.
"""
function update_plot_data!(x, y, dataframe, ax, new_x, new_y, xlabel, ylabel, ptitle, df)
    # Update observables atomically to avoid dimension mismatches
    x.val = new_x
    y.val = new_y
    dataframe.val = df

    # Notify all observables at once
    notify(x)
    notify(y)
    notify(dataframe)

    ax.title = ptitle
    ax.xlabel = xlabel
    ax.ylabel = ylabel
    autolimits!(ax)
end

"""
    watch_and_process_files(datadir, file_ext, load_function, waittime, x, y, dataframe, ax, stop_signal)

Watches for new files in the directory and processes them when found.
Exits gracefully when stop_signal[] becomes true.
waittime is only used for pausing after errors before retry.
"""
function watch_and_process_files(datadir, file_ext, load_function, waittime, x, y, dataframe, ax, stop_signal)
    # Use a task for non-blocking file watching
    watch_task = @async begin
        while !stop_signal[]
            try
                (file, event) = watch_folder(datadir)

                # Check stop signal again after watch returns
                if stop_signal[]
                    break
                end

                if endswith(file, file_ext)
                    # Remove leading path separators that some file systems may include
                    file = lstrip(file, ['/', '\\'])

                    filepath = joinpath(datadir, file)
                    println("New file: ", file)

                    try
                        new_x, new_y, xlabel, ylabel, ptitle, df = load_function(filepath)

                        if new_x !== nothing && new_y !== nothing
                            update_plot_data!(x, y, dataframe, ax, new_x, new_y, xlabel, ylabel, ptitle, df)
                        end
                    catch e
                        println("Error loading file $file: ", e)
                        continue
                    end
                end
            catch e
                if isa(e, InterruptException) || stop_signal[]
                    println("Monitoring interrupted")
                    break
                else
                    println("Error watching folder: ", e)
                    sleep(waittime)  # Brief pause before retrying
                    continue
                end
            end
        end
        println("File monitoring stopped")
    end

    # Wait for the task while checking stop signal periodically
    while !istaskdone(watch_task) && !stop_signal[]
        sleep(0.1)  # Check every 100ms
    end

    # Ensure the task is finished
    if !istaskdone(watch_task)
        try
            # Try to interrupt the task gracefully
            schedule(watch_task, InterruptException(), error=true)
            wait(watch_task)
        catch
            # Task may have already finished
        end
    end
end

"""
    live_plot(datadir::String, load_function::Function=load_mir, file_ext::String=".lvm"; waittime = 1.0)

A panel with a plot that updates when a new data file is found
in the given directory. Satellite panels can be opened via buttons.

# Arguments
- `datadir::String`: Path to directory to monitor for new files
- `load_function::Function`: Function to load and parse data files (default: load_mir)
- `file_ext::String`: File extension to watch for (default: ".lvm")
- `waittime::Float64`: Sleep duration between file checks in seconds (default: 1.0)
"""
function live_plot(
        datadir::String,
        load_function::Function=load_mir,
        file_ext::String=".lvm";
        waittime::Float64 = 1.0,
    )

    # Parameter validation
    if !isdir(datadir)
        throw(ArgumentError("Directory does not exist: $datadir"))
    end
    if waittime <= 0
        throw(ArgumentError("waittime must be positive, got: $waittime"))
    end
    if !startswith(file_ext, ".")
        throw(ArgumentError("file_ext must start with '.', got: $file_ext"))
    end

    datadir = abspath(datadir)

    # Setup GUI components
    fig, ax, x, y, dataframe, stop_signal = setup_live_plot_gui()

    try
        # Watch for new data
        watch_and_process_files(datadir, file_ext, load_function, waittime, x, y, dataframe, ax, stop_signal)
    catch e
        if isa(e, InterruptException)
            println("Live plot interrupted by user")
        else
            println("Unexpected error in live plot: ", e)
            rethrow(e)
        end
    finally
        # Cleanup resources
        println("Monitoring cleanup completed")
    end

end

"""
    satellite_panel(df::DataFrame, title)

A satellite panel that appears upon clicking a button on the live panel.
Not a user-facing function.
"""
function satellite_panel(df::DataFrame, xlabel, ylabel, title)

    fig = Figure()
    DataInspector(fig)

    colnames = names(df)

    # x unit labels
    wavelen = "Wavelength (nm)"
    wavenum = "Wavenumber (cm⁻¹)"
    fs = "Pump delay (fs)"
    ps = "Pump delay (ps)"

    # Observables and widgets
    x = Observable(df[!, 1])
    y = Observable(df[!, 2])  # automatically plot difference data if it exists
    save_button = Button(fig, label = "Save as PDF")
    xunits_button = Button(fig, label = "Change x units")
    flip_yaxis = Button(fig, label = "Flip y-axis")
    
    # Draw figure

    fig[1, 1][1, 1] = vgrid!(
        xunits_button,
        flip_yaxis,
        save_button;
        tellheight = false
        )

    ax = Axis(fig[1, 2],
        title = title,
        xlabel = xlabel,
        ylabel = ylabel, 
        xticks = LinearTicks(7),
        yticks = LinearTicks(5)
        )
    lineplots = [lines!(ax, x, y, color = :indigo, label = "ΔT", visible = true)]


    # Buttons and Interactivity

    if length(colnames) > 2
        transmission_button = Button(fig[2, 2][1, 1], label = "Pump on/off", tellwidth = false)
        difference_button = Button(fig[2, 2][1, 2], label = "ΔT", tellwidth = false)

        push!(lineplots, lines!(ax, x, -df.off, color = :deepskyblue3, label = "pump off", visible = false))
        push!(lineplots, lines!(ax, x, -df.on, color = :crimson, label = "pump on", visible = false))
        Legend(fig[1, 1][2, 1], ax)

        on(difference_button.clicks) do _
                lineplots[1].visible = true
                lineplots[2].visible = false
                lineplots[3].visible = false
                ax.ylabel = "ΔT"
                autolimits!(ax)
        end
        on(transmission_button.clicks) do _
                lineplots[1].visible = false
                lineplots[2].visible = true
                lineplots[3].visible = true
                ax.ylabel = "Pump on/off transmission (arb.)"
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

    on(flip_yaxis.clicks) do _
        y[] = -y[]
        autolimits!(ax)
    end

    on(save_button.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end

        plotname = to_value(title)
        save_path = abspath(joinpath(save_folder, plotname * ".pdf"))
        to_save = make_savefig(x, y, plotname, to_value(ax.xlabel), to_value(ax.ylabel))
        save(save_path, to_save, backend = CairoMakie)
        println("Saved figure to ", save_path)
    end
    
    return fig
end

