"""
    setup_live_plot_gui(datadir, file_ext, load_function)

Creates and configures the GUI components for live plotting.
Returns the figure, axis, and observables needed for live updates.
"""
function setup_live_plot_gui(datadir, file_ext, load_function)
    GLMakie.activate!()

    # Apply lab monitor theme
    set_theme!(dataviewer_theme())
    colors = dataviewer_colors()

    fig = Figure(size = (650, 500))
    sc = display(fig)
    DataInspector(fig)

    x = Observable(rand(1))
    y = Observable(rand(1))
    data_container = Observable{Any}(nothing)  # Holds PumpProbeData or NamedTuple

    ax = Axis(fig[1, 1], xticks = LinearTicks(7), yticks = LinearTicks(5))
    line = lines!(x, y, color = colors[:data], linewidth = 1.5)
    livetext = text!(" • Live", color = colors[:accent], space = :relative, align = (:left, :bottom))

    figbutton = Button(fig, label = "New Figure")
    themebutton = Button(fig, label = "Light Mode")
    fig[2, 1] = hgrid!(
        figbutton,
        themebutton;
        tellwidth = false,
        )

    # Track current theme (true = dark, false = light)
    is_dark_theme = Ref(true)

    # Collect elements for theme switching
    all_buttons = [figbutton, themebutton]
    plots = [(line, :data)]
    texts = [(livetext, :accent)]

    # Button Actions
    on(figbutton.clicks) do _
        newfig = satellite_panel(to_value(data_container), to_value(ax.xlabel), to_value(ax.ylabel), to_value(ax.title), datadir, file_ext, load_function; dark_theme=is_dark_theme[])
        display(GLMakie.Screen(), newfig)
    end

    on(themebutton.clicks) do _
        is_dark_theme[] = !is_dark_theme[]
        apply_theme!(fig, ax, plots, all_buttons; dark=is_dark_theme[], texts=texts)
        themebutton.label = is_dark_theme[] ? "Light Mode" : "Dark Mode"
    end

    return fig, ax, x, y, data_container
end

"""
    update_plot_data!(x, y, data_container, ax, new_x, new_y, xlabel, ylabel, ptitle, df)

Updates the plot observables and axis labels with new data.
"""
function update_plot_data!(x, y, data_container, ax, new_x, new_y, xlabel, ylabel, ptitle, df)
    # Update observables atomically to avoid dimension mismatches
    x.val = new_x
    y.val = new_y
    data_container.val = df

    # Notify all observables at once
    notify(x)
    notify(y)
    notify(data_container)

    ax.title = ptitle
    ax.xlabel = xlabel
    ax.ylabel = ylabel
    autolimits!(ax)
end

"""
    watch_and_process_files(datadir, file_ext, load_function, waittime, x, y, data_container, ax)

Watches for new files in the directory and processes them when found.
Runs until interrupted.
"""
function watch_and_process_files(datadir, file_ext, load_function, waittime, x, y, data_container, ax)
    seen_files = get!(() -> Set{String}(), _watcher_registry, _normdir(datadir))

    while true
        try
            (file, event) = watch_folder(datadir)

            if endswith(file, file_ext)
                # Remove leading path separators that some file systems may include
                file = lstrip(file, ['/', '\\'])

                # Skip if we've already processed this file
                if file in seen_files
                    continue
                end

                filepath = joinpath(datadir, file)

                # Skip if file was deleted before we could process it
                # (e.g. cleanup! triggers deletion events — don't mark as seen)
                if !isfile(filepath)
                    continue
                end
                push!(seen_files, file)

                println("New file: ", file)

                try
                    new_x, new_y, xlabel, ylabel, ptitle, df = load_function(filepath)

                    if new_x !== nothing && new_y !== nothing
                        update_plot_data!(x, y, data_container, ax, new_x, new_y, xlabel, ylabel, ptitle, df)
                    end
                catch e
                    println("Error loading file $file: ", e)
                    continue
                end
            end
        catch e
            if isa(e, InterruptException)
                println("Monitoring stopped")
                break
            else
                println("Error watching folder: ", e)
                sleep(waittime)
                continue
            end
        end
    end
end

"""
    live_plot(datadir::String, load_function::Function=load_mir, file_ext::String=".lvm"; waittime::Float64 = 1.0, async::Bool = true)

A panel with a plot that updates when a new data file is found
in the given directory. Satellite panels can be opened via buttons.

By default, runs in the background and returns control to REPL immediately.

# Arguments
- `datadir::String`: Path to directory to monitor for new files
- `load_function::Function`: Function to load and parse data files (default: load_mir)
- `file_ext::String`: File extension to watch for (default: ".lvm")
- `waittime::Float64`: Sleep duration between file checks in seconds (default: 1.0)
- `async::Bool`: If true (default), runs in background and returns Task; if false, blocks until stopped

# Returns
- If `async=true` (default): Returns a Task for the background monitoring
- If `async=false`: Returns nothing (blocks until stopped)

# Examples
```julia
# Non-blocking (default) - REPL stays available
task = live_plot("./data")

# Blocking behavior if needed
live_plot("./data", async=false)
```
"""
function live_plot(
        datadir::String,
        load_function::Function=load_mir,
        file_ext::String=".lvm";
        waittime::Float64 = 1.0,
        async::Bool = true,
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

    if async
        println("Starting live plot in background...")
        println("  Directory: $datadir")
        println("  File extension: $file_ext")

        # Use the approach that actually works!
        task = @async begin
            # Setup GUI components
            fig, ax, x, y, data_container = setup_live_plot_gui(datadir, file_ext, load_function)

            try
                # Watch for new data
                watch_and_process_files(datadir, file_ext, load_function, waittime, x, y, data_container, ax)
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

        println("  Live plot started! REPL is now available.")
        return task
    else
        # Blocking behavior
        # Setup GUI components
        fig, ax, x, y, data_container = setup_live_plot_gui(datadir, file_ext, load_function)

        try
            # Watch for new data
            watch_and_process_files(datadir, file_ext, load_function, waittime, x, y, data_container, ax)
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

        return nothing
    end

end

"""
    satellite_panel(data, xlabel, ylabel, title, datadir, file_ext, load_function; dark_theme=true)

A satellite panel that appears upon clicking a button on the live panel.
Handles PumpProbeData (LVM) and NamedTuple (CSV test data).
Inherits theme from the live panel via `dark_theme` parameter.

Includes a file history Menu to browse and reload other files in the
monitored directory without opening a new panel.
"""
function satellite_panel(data, xlabel, ylabel, title, datadir, file_ext, load_function; dark_theme::Bool=true)
    colors = dataviewer_colors(dark_theme)

    fig = Figure(size = (750, 500))
    DataInspector(fig)

    # x unit labels (from AXIS_LABELS)
    wavelen = AXIS_LABELS.wavelength
    wavenum = AXIS_LABELS.wavenumber

    # Handle PumpProbeData and NamedTuple
    if data isa QPS.PumpProbeData
        x_data = QPS.xaxis(data)
        y_data = data.diff[:, 1]
        has_pump_data = true
        on_data = data.on[:, 1]
        off_data = data.off[:, 1]
    elseif data isa NamedTuple
        x_data = data.x
        y_data = data.y
        has_pump_data = false
        on_data = Float64[]
        off_data = Float64[]
    else
        error("Unsupported data type: $(typeof(data))")
    end

    # Observables
    x = Observable(x_data)
    y = Observable(y_data)
    y_fit = Observable(fill(NaN, length(x_data)))
    on_obs = Observable(on_data)
    off_obs = Observable(off_data)
    fit_result = Ref{Union{Nothing, QPS.ExpDecayIRFFit}}(nothing)
    fit_t_start = Ref{Float64}(0.0)

    # Peak finder state
    is_spectral = Ref(_is_spectral_data(data, xlabel))
    esa_x = Observable(Float64[])
    esa_y = Observable(Float64[])
    gsb_x = Observable(Float64[])
    gsb_y = Observable(Float64[])
    peak_text_obs = Observable{Any}("")

    # Track current theme (inherited from live panel)
    is_dark_theme = Ref(dark_theme)

    # Build file list for history menu
    available_files = sort(filter(f -> endswith(f, file_ext), readdir(datadir)))
    current_file = title  # title is the filename stem
    # Find the matching full filename for pre-selection
    default_idx = findfirst(f -> startswith(f, current_file), available_files)
    default_label = default_idx !== nothing ? available_files[default_idx] : (isempty(available_files) ? "" : available_files[1])

    # Create widgets
    file_menu = Menu(fig, options = available_files, default = default_label, width = 200,
        textcolor = Makie.to_color(colors[:foreground]),
        cell_color_inactive_even = Makie.to_color(colors[:btn_bg]),
        cell_color_inactive_odd = Makie.to_color(colors[:btn_bg]),
        cell_color_hover = let bg = Makie.to_color(colors[:btn_bg]), fg = Makie.to_color(colors[:foreground]), t = 0.25f0
            Makie.RGBAf(bg.r + t*(fg.r - bg.r), bg.g + t*(fg.g - bg.g), bg.b + t*(fg.b - bg.b), 1.0f0)
        end,
        cell_color_active = Makie.to_color(colors[:accent]),
        selection_cell_color_inactive = Makie.to_color(colors[:btn_bg]),
        dropdown_arrow_color = Makie.to_color(colors[:foreground]))
    save_button = Button(fig, label = "Save as PDF")
    xunits_button = Button(fig, label = "Change x units")
    themebutton = Button(fig, label = dark_theme ? "Light Mode" : "Dark Mode")
    fitbutton = Button(fig, label = is_spectral[] ? "Find Peaks" : "Fit")
    t0_label = Label(fig, "t₀ (ps):", fontsize = 14, color = colors[:foreground],
        visible = !is_spectral[])
    t0_box = Textbox(fig, stored_string = "1.0", width = 80,
        textcolor = colors[:foreground],
        boxcolor = colors[:background],
        bordercolor = colors[:foreground],
        height = is_spectral[] ? 0 : Auto())

    # Draw figure - button panel on left with fixed width
    fig[1, 1] = vgrid!(
        file_menu,
        xunits_button,
        save_button,
        themebutton,
        t0_label,
        t0_box,
        fitbutton;
        tellheight = false,
        width = 220
        )

    ax = Axis(fig[1, 2],
        title = title,
        xlabel = xlabel,
        ylabel = ylabel,
        xticks = LinearTicks(7),
        yticks = LinearTicks(5),
        )

    # Set figure and axis backgrounds (theme sets defaults but we override for inherited theme)
    fig.scene.backgroundcolor[] = Makie.to_color(colors[:background])
    apply_theme_to_axis!(ax, colors)

    # Plot elements
    diff_line = lines!(ax, x, y, color = colors[:diff], linewidth = 1.5, label = "ΔT", visible = true)
    fit_line = lines!(ax, x, y_fit, color = colors[:fit], linewidth = 1.5, visible = false)
    fit_text = text!(ax, 0.98, 0.5, text = "", space = :relative, align = (:right, :center),
                     color = colors[:foreground], fontsize = 14, visible = false)

    # Peak finder visualization
    esa_scatter = scatter!(ax, esa_x, esa_y, color = colors[:warning],
        marker = :dtriangle, markersize = 12, visible = false)
    gsb_scatter = scatter!(ax, gsb_x, gsb_y, color = colors[:fit],
        marker = :utriangle, markersize = 12, visible = false)
    peak_text = text!(ax, 0.02, 0.98, text = peak_text_obs, space = :relative,
        align = (:left, :top), fontsize = 12, visible = false)

    # Collect elements for theme switching
    all_buttons = [save_button, xunits_button, themebutton, fitbutton]
    plots = [(diff_line, :diff), (fit_line, :fit), (esa_scatter, :warning), (gsb_scatter, :fit)]
    texts = [(fit_text, :foreground)]
    legend = nothing

    # Derived observables for pump lines (negated for display)
    neg_off = @lift(-$off_obs)
    neg_on = @lift(-$on_obs)

    # Refs for pump line objects (populated if pump data exists)
    off_line_ref = Ref{Any}(nothing)
    on_line_ref = Ref{Any}(nothing)
    signal_toggle_ref = Ref{Any}(nothing)
    showing_diff = Ref(true)

    # Add pump on/off lines if data available
    if has_pump_data && length(on_data) > 0
        signal_toggle = Button(fig[2, 2], label = "Show pump on/off", tellwidth = false)
        signal_toggle_ref[] = signal_toggle

        off_line = lines!(ax, x, neg_off, color = colors[:pump_off], linewidth = 1.5, label = "pump off", visible = false)
        on_line = lines!(ax, x, neg_on, color = colors[:pump_on], linewidth = 1.5, label = "pump on", visible = false)
        off_line_ref[] = off_line
        on_line_ref[] = on_line

        push!(plots, (off_line, :pump_off))
        push!(plots, (on_line, :pump_on))

        legend = axislegend(ax, position = :rb,
            backgroundcolor = (Makie.to_color(colors[:background]), 0.8),
            labelcolor = Makie.to_color(colors[:foreground]),
            framecolor = Makie.to_color(colors[:foreground]))

        on(signal_toggle.clicks) do _
            showing_diff[] = !showing_diff[]
            if showing_diff[]
                Makie.update!(diff_line; visible = true)
                Makie.update!(off_line; visible = false)
                Makie.update!(on_line; visible = false)
                ax.ylabel = AXIS_LABELS.diff
                signal_toggle.label = "Show pump on/off"
            else
                Makie.update!(diff_line; visible = false)
                Makie.update!(off_line; visible = true)
                Makie.update!(on_line; visible = true)
                Makie.update!(fit_line; visible = false)
                Makie.update!(fit_text; visible = false)
                Makie.update!(esa_scatter; visible = false)
                Makie.update!(gsb_scatter; visible = false)
                Makie.update!(peak_text; visible = false)
                ax.ylabel = AXIS_LABELS.transmission
                signal_toggle.label = "Show −ΔT"
            end
            autolimits!(ax)
        end
        push!(all_buttons, signal_toggle)
    end

    # File history menu callback
    on(file_menu.selection) do selected_file
        selected_file === nothing && return
        filepath = joinpath(datadir, selected_file)
        try
            result = load_function(filepath)
            if result === nothing || result[1] === nothing
                println("Could not load file: ", selected_file)
                return
            end

            new_x, new_y, new_xlabel, new_ylabel, new_title, new_data = result

            # Extract pump data from loaded result
            if new_data isa QPS.PumpProbeData
                new_on = new_data.on[:, 1]
                new_off = new_data.off[:, 1]
            elseif new_data isa NamedTuple
                new_on = Float64[]
                new_off = Float64[]
            else
                new_on = Float64[]
                new_off = Float64[]
            end

            # Update all observables atomically
            x.val = new_x
            y.val = new_y
            y_fit.val = fill(NaN, length(new_x))
            on_obs.val = new_on
            off_obs.val = new_off
            notify(x)
            notify(y)
            notify(y_fit)
            notify(on_obs)
            notify(off_obs)

            # Reset fit state
            fit_result[] = nothing
            Makie.update!(fit_line; visible = false)
            Makie.update!(fit_text; visible = false)

            # Clear peak markers
            esa_x[] = Float64[]
            esa_y[] = Float64[]
            gsb_x[] = Float64[]
            gsb_y[] = Float64[]
            peak_text_obs[] = ""
            Makie.update!(esa_scatter; visible = false)
            Makie.update!(gsb_scatter; visible = false)
            Makie.update!(peak_text; visible = false)

            # Detect spectral vs kinetics mode
            is_spectral[] = _is_spectral_data(new_data, new_xlabel)
            fitbutton.label = is_spectral[] ? "Find Peaks" : "Fit"
            t0_label.visible = !is_spectral[]
            t0_box.height = is_spectral[] ? 0 : Auto()

            # Update axis labels and title
            ax.title = new_title
            ax.xlabel = new_xlabel
            ax.ylabel = new_ylabel

            # Reset to diff view if pump toggle exists
            if signal_toggle_ref[] !== nothing
                showing_diff[] = true
                Makie.update!(diff_line; visible = true)
                if off_line_ref[] !== nothing
                    Makie.update!(off_line_ref[]; visible = false)
                    Makie.update!(on_line_ref[]; visible = false)
                end
                signal_toggle_ref[].label = "Show pump on/off"
            end

            autolimits!(ax)
            println("Loaded: ", selected_file)
        catch e
            println("Error loading file ", selected_file, ": ", e)
        end
    end

    # Button callbacks
    on(xunits_button.clicks) do _
        current_label = to_value(ax.xlabel)
        if current_label == wavelen
            x[] = 10^7 ./ x[]
            ax.xlabel = wavenum
        elseif current_label == wavenum
            x[] = 10^7 ./ x[]
            ax.xlabel = wavelen
        elseif current_label == AXIS_LABELS.time_fs
            x[] = x[] ./ 1000
            ax.xlabel = AXIS_LABELS.time_ps
        elseif current_label == AXIS_LABELS.pump_delay_fs
            x[] = x[] ./ 1000
            ax.xlabel = AXIS_LABELS.pump_delay_ps
        elseif current_label == AXIS_LABELS.time_ps
            x[] = x[] .* 1000
            ax.xlabel = AXIS_LABELS.time_fs
        elseif current_label == AXIS_LABELS.pump_delay_ps
            x[] = x[] .* 1000
            ax.xlabel = AXIS_LABELS.pump_delay_fs
        end
        # Convert peak marker positions to match new x units
        if esa_scatter.visible[] || gsb_scatter.visible[]
            if current_label == wavelen || current_label == wavenum
                if !isempty(esa_x[])
                    esa_x[] = 10^7 ./ esa_x[]
                end
                if !isempty(gsb_x[])
                    gsb_x[] = 10^7 ./ gsb_x[]
                end
                peak_text_obs[] = _build_peak_text(esa_x[], gsb_x[])
            end
        end
        autolimits!(ax)
    end

    # Helper function to perform fitting
    # Fits only the decay region: from t_start onward.
    # Raw data is never shifted — t_start only controls which region is
    # passed to the fitter, preserving original delay-stage positions.
    function do_fit!()
        x_vals = to_value(x)
        y_vals = to_value(y)

        # Use t0 from textbox, fall back to max(peak, 1.0 ps)
        t_peak = QPS.find_peak_time(x_vals, y_vals)
        t0_str = t0_box.displayed_string[]
        t_start = something(tryparse(Float64, t0_str), max(t_peak, 1.0))
        fit_t_start[] = t_start
        t0_box.displayed_string = string(round(t_start, digits=2))

        trace = QPS.TATrace(x_vals, y_vals)
        result = QPS.fit_exp_decay(trace; irf=false, t_start=t_start)
        fit_result[] = result

        # Only show fit line in the fitted region (NaN hides the rest)
        y_predicted = fill(NaN, length(x_vals))
        fit_mask = x_vals .>= t_start
        y_predicted[fit_mask] = QPS.predict(result, x_vals[fit_mask])
        y_fit[] = y_predicted

        τ_str = round(result.tau, digits=2)
        r2_str = round(result.rsquared, digits=4)
        fit_text.text = "τ = $(τ_str) ps\nR² = $(r2_str)"

        Makie.update!(fit_line; visible = true)
        Makie.update!(fit_text; visible = true)

        println("Fit: τ = $(τ_str) ps, R² = $(r2_str) (fit from $(round(t_start, digits=2)) ps)")
        return result
    end

    # Format peak position as a label string with appropriate precision
    _peak_label(pos) = string(round(pos, digits=1))

    # Build colored rich text listing peak positions
    function _build_peak_text(esa_positions, gsb_positions)
        c = dataviewer_colors(is_dark_theme[])
        parts = Union{Makie.RichText, String}[]
        for (i, pos) in enumerate(esa_positions)
            i > 1 && push!(parts, "\n")
            push!(parts, rich("ESA: $(_peak_label(pos))", color=c[:warning]))
        end
        for (i, pos) in enumerate(gsb_positions)
            (!isempty(esa_positions) || i > 1) && push!(parts, "\n")
            push!(parts, rich("GSB: $(_peak_label(pos))", color=c[:fit]))
        end
        isempty(parts) ? "" : rich(parts...)
    end

    function do_find_peaks!()
        x_vals = to_value(x)
        y_vals = to_value(y)

        # ESA peaks (positive, excited-state absorption)
        esa_peaks = QPS.find_peaks(x_vals, y_vals; min_prominence=0.05)
        # GSB dips (negative, ground-state bleach) — negate to find peaks, recover original y
        gsb_peaks = QPS.find_peaks(x_vals, -y_vals; min_prominence=0.05)

        # Update ESA observables
        esa_x[] = [p.position for p in esa_peaks]
        esa_y[] = [p.intensity for p in esa_peaks]

        # Update GSB observables (use original negative y values)
        gsb_x[] = [p.position for p in gsb_peaks]
        gsb_y[] = [-p.intensity for p in gsb_peaks]

        # Build colored annotation text
        peak_text_obs[] = _build_peak_text(esa_x[], gsb_x[])

        # Show markers
        Makie.update!(esa_scatter; visible = length(esa_peaks) > 0)
        Makie.update!(gsb_scatter; visible = length(gsb_peaks) > 0)
        Makie.update!(peak_text; visible = true)

        # Print peak table to REPL
        xlab = to_value(ax.xlabel)
        if !isempty(esa_peaks)
            println("ESA peaks ($xlab):")
            println(QPS.peak_table(esa_peaks))
        end
        if !isempty(gsb_peaks)
            println("GSB peaks ($xlab):")
            println(QPS.peak_table(gsb_peaks))
        end
        if isempty(esa_peaks) && isempty(gsb_peaks)
            println("No peaks detected")
        end
    end

    function try_fit!()
        current_xlabel = to_value(ax.xlabel)
        if current_xlabel == wavelen || current_xlabel == wavenum
            println("Spectral fitting not supported — use desk analysis")
            return
        end
        try
            do_fit!()
        catch e
            println("Fit failed: ", e)
            Makie.update!(fit_line; visible = false)
            Makie.update!(fit_text; visible = false)
        end
    end

    on(fitbutton.clicks) do _
        if is_spectral[]
            try
                do_find_peaks!()
            catch e
                println("Peak finding failed: ", e)
            end
        else
            try_fit!()
        end
    end

    on(t0_box.stored_string) do _
        if !is_spectral[]
            try_fit!()
        end
    end

    on(save_button.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end

        plotname = to_value(ax.title)
        save_path = abspath(joinpath(save_folder, plotname * ".pdf"))
        to_save = make_savefig(x, y, plotname, to_value(ax.xlabel), to_value(ax.ylabel))
        save(save_path, to_save, backend = CairoMakie)
        println("Saved figure to ", save_path)
    end

    on(themebutton.clicks) do _
        is_dark_theme[] = !is_dark_theme[]
        new_colors = apply_theme!(fig, ax, plots, all_buttons; dark=is_dark_theme[], legend=legend, texts=texts)
        themebutton.label = is_dark_theme[] ? "Light Mode" : "Dark Mode"
        t0_label.color = new_colors[:foreground]
        t0_box.textcolor = new_colors[:foreground]
        t0_box.boxcolor = new_colors[:background]
        t0_box.bordercolor = new_colors[:foreground]
        file_menu.textcolor = Makie.to_color(new_colors[:foreground])
        file_menu.cell_color_inactive_even = Makie.to_color(new_colors[:btn_bg])
        file_menu.cell_color_inactive_odd = Makie.to_color(new_colors[:btn_bg])
        file_menu.cell_color_hover = let bg = Makie.to_color(new_colors[:btn_bg]), fg = Makie.to_color(new_colors[:foreground]), t = 0.25f0
            Makie.RGBAf(bg.r + t*(fg.r - bg.r), bg.g + t*(fg.g - bg.g), bg.b + t*(fg.b - bg.b), 1.0f0)
        end
        file_menu.cell_color_active = Makie.to_color(new_colors[:accent])
        file_menu.selection_cell_color_inactive = Makie.to_color(new_colors[:btn_bg])
        # Makie Menu doesn't reactively bind selection_cell_color_inactive to its
        # polygon — the color only refreshes on hover. Poke the poly directly.
        file_menu.blockscene.plots[1].color = Makie.to_color(new_colors[:btn_bg])
        file_menu.dropdown_arrow_color = Makie.to_color(new_colors[:foreground])
        # Fix dropdown option text color (Makie Menu doesn't bind this to textcolor)
        for child in file_menu.blockscene.children
            for plot in child.plots
                if plot isa Makie.Text
                    plot.color = Makie.to_color(new_colors[:foreground])
                end
            end
        end
    end

    return fig
end
