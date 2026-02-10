# Live CCD heatmap panel for transient absorption data
# Watches for CCDABS + T_scale file pairs and displays ΔA heatmaps
# with a mouse-tracked line profiler.
#
# Data convention:
#   Raw matrix from load_image is (n_rows, n_cols) = (n_time, n_wavelength).
#   Standard TA convention: x = wavelength, y = time.
#   We transpose the matrix so the first index maps to x (wavelength)
#   and the second to y (time), matching standard TA heatmap orientation.
#
# Rendering uses Makie.update! for atomic plot updates instead of
# Observable reactivity. Data is stored in plain Refs.

# Transpose raw (n_time, n_wavelength) matrix so heatmap x=wavelength, y=time
_orient_ccd(img) = collect(img')

"""
    _find_wavelength_file(datadir)

Auto-detect a wavelength axis file in `datadir`. Looks for files starting
with "wavelength", "lambda", or "wl_axis" (case-insensitive).

Returns the full path if found, `nothing` otherwise.
"""
function _find_wavelength_file(datadir)
    for f in readdir(datadir)
        fname = lowercase(f)
        if any(p -> startswith(fname, p), ("wavelength", "lambda", "wl_axis"))
            return joinpath(datadir, f)
        end
    end
    return nothing
end

function setup_ccd_gui(datadir)
    GLMakie.activate!()
    set_theme!(dataviewer_theme())
    colors = dataviewer_colors()

    fig = Figure(size=(800, 900))
    sc = display(fig)
    DataInspector(fig)

    # Data storage — plain Refs, no Observable reactivity
    wl_ref = Ref(collect(1.0:10.0))
    time_ref = Ref(collect(1.0:10.0))
    img_ref = Ref(zeros(10, 10))
    raw_ref = Ref(zeros(10, 10))
    x_idx = Ref(1)

    # Heatmap axis (x=wavelength, y=time)
    ax1 = Axis(fig[1, 1][1, 1],
        title="Waiting for data...",
        xlabel=AXIS_LABELS.wavelength,
        ylabel=AXIS_LABELS.time_ps,
        xticks=LinearTicks(7),
        yticks=LinearTicks(7))
    hm = heatmap!(ax1, wl_ref[], time_ref[], img_ref[], colormap=:RdBu, colorrange=(-0.01, 0.01))
    vl = vlines!(ax1, wl_ref[][1], color=:red)
    cb = Colorbar(fig[1, 1][1, 2], hm, label=AXIS_LABELS.delta_a)

    livetext = text!(" • Live", color=Makie.to_color(colors[:accent]),
        space=:relative, align=(:left, :bottom))

    # Cut axis (line profiler) — kinetic trace at selected wavelength
    ax2 = Axis(fig[1, 1][2, 1],
        xlabel=AXIS_LABELS.time_ps,
        ylabel=AXIS_LABELS.delta_a,
        xticks=LinearTicks(7),
        yticks=LinearTicks(5),
        yticklabelspace=55.0)
    cut_line = lines!(ax2, [Point2f(0, 0)], color=Makie.to_color(colors[:data]), linewidth=1.5)

    # Buttons
    figbutton = Button(fig, label="New Figure")
    wlbutton = Button(fig, label="Load λ axis")
    themebutton = Button(fig, label="Light Mode")
    fig[2, 1] = hgrid!(figbutton, wlbutton, themebutton; tellwidth=false)

    # Theme tracking
    is_dark_theme = Ref(true)
    all_buttons = [figbutton, wlbutton, themebutton]
    plots = [(cut_line, :data)]
    texts = [(livetext, :accent)]

    # Mouse tracking — find nearest wavelength on heatmap, update via Makie.update!
    on(events(fig).mouseposition) do mpos
        if is_mouseinside(ax1)
            wl_pos = mouseposition(ax1.scene)[1]
            wl_vec = wl_ref[]
            idx = argmin(abs.(wl_vec .- wl_pos))
            x_idx[] = idx
            Makie.update!(vl; arg1=wl_vec[idx])
            img_data = img_ref[]
            t = time_ref[]
            slice = img_data[clamp(idx, 1, size(img_data, 1)), :]
            n = min(length(t), length(slice))
            Makie.update!(cut_line; arg1=[Point2f(t[i], slice[i]) for i in 1:n])
            autolimits!(ax2)
        end
    end

    on(figbutton.clicks) do _
        newfig = satellite_ccd(raw_ref[], time_ref[], wl_ref[],
            String(to_value(ax1.title)); dark_theme=is_dark_theme[], datadir=datadir,
            xlabel=String(to_value(ax1.xlabel)), ylabel=String(to_value(ax1.ylabel)))
        display(GLMakie.Screen(), newfig)
    end

    on(wlbutton.clicks) do _
        wl_file = _find_wavelength_file(datadir)
        if wl_file !== nothing && isfile(wl_file)
            wl_vals = load_axis_file(wl_file)
            wl_ref[] = wl_vals
            Makie.update!(hm; arg1=wl_vals)
            Makie.update!(vl; arg1=wl_vals[clamp(x_idx[], 1, length(wl_vals))])
            ax1.xlabel = AXIS_LABELS.wavelength
            reset_limits!(ax1)
            println("Loaded wavelength axis: ", basename(wl_file))
        else
            println("No wavelength file found in ", datadir)
            println("  Expected: wavelength*.txt, lambda*.txt, or wl_axis*.txt")
        end
    end

    on(themebutton.clicks) do _
        is_dark_theme[] = !is_dark_theme[]
        apply_theme!(fig, [ax1, ax2], plots, all_buttons;
            dark=is_dark_theme[], texts=texts, colorbars=[cb])
        themebutton.label = is_dark_theme[] ? "Light Mode" : "Dark Mode"
    end

    return (fig=fig, ax1=ax1, ax2=ax2, hm=hm, vl=vl, cut_line=cut_line,
            wl=wl_ref, time=time_ref, img=img_ref, raw=raw_ref,
            x_idx=x_idx, is_dark_theme=is_dark_theme)
end

function update_ccd_data!(gui, new_img, filename, time_vals)
    oriented = _orient_ccd(new_img)
    n_wl = size(oriented, 1)
    if length(gui.wl[]) != n_wl
        gui.wl[] = collect(1.0:n_wl)
    end
    gui.time[] = time_vals
    gui.img[] = oriented
    gui.raw[] = new_img

    max_abs = maximum(abs, oriented)
    cr = max_abs > 0 ? (-max_abs, max_abs) : (-0.01, 0.01)
    Makie.update!(gui.hm, gui.wl[], time_vals, oriented; colorrange=cr)

    # Update cut at current cursor
    idx = clamp(gui.x_idx[], 1, n_wl)
    slice = oriented[idx, :]
    n = min(length(time_vals), length(slice))
    Makie.update!(gui.cut_line; arg1=[Point2f(time_vals[i], slice[i]) for i in 1:n])
    Makie.update!(gui.vl; arg1=gui.wl[][idx])

    gui.ax1.title = filename
    reset_limits!(gui.ax1)
    autolimits!(gui.ax2)
end

function watch_and_process_ccd(datadir, file_ext, waittime, gui)
    seen_files = get!(() -> Set{String}(), _watcher_registry, _normdir(datadir))

    while true
        try
            (file, event) = watch_folder(datadir)

            if endswith(file, file_ext)
                file = lstrip(file, ['/', '\\'])

                filepath = joinpath(datadir, file)
                if !isfile(filepath)
                    continue
                end

                # Only trigger on CCDABS files
                if !startswith(file, "CCDABS")
                    continue
                end

                if file in seen_files
                    continue
                end
                push!(seen_files, file)

                println("New CCD file: ", file)

                new_img, filename = load_image(filepath)
                if new_img !== nothing
                    # Look for matching T_scale file
                    scan_id = replace(file, "CCDABS" => "", file_ext => "")
                    tscale_path = joinpath(datadir, "T_scale$(scan_id)$(file_ext)")
                    if isfile(tscale_path)
                        time_vals = load_axis_file(tscale_path)
                    else
                        time_vals = collect(1.0:size(new_img, 1))
                        gui.ax1.ylabel = AXIS_LABELS.pixel_row
                    end
                    update_ccd_data!(gui, new_img, filename, time_vals)
                end
            end
        catch e
            if isa(e, InterruptException)
                println("CCD monitoring stopped")
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
    live_ccd(datadir; file_ext=".lvm", waittime=0.1, async=true, wavelength_file=nothing)

Live heatmap panel for CCD transient absorption data. Watches `datadir`
for CCDABS + T_scale file pairs and displays ΔA heatmaps with a
diverging RdBu colormap and mouse-tracked kinetic trace profiler.

Axes follow standard TA convention: x = wavelength (nm), y = time (ps).

# Arguments
- `datadir::String`: Directory to monitor for CCD data files
- `file_ext::String`: File extension to watch (default: ".lvm")
- `waittime::Float64`: Sleep between file checks in seconds (default: 0.1)
- `async::Bool`: If true (default), runs in background and returns Task
- `wavelength_file`: Path to wavelength axis file. If `nothing`, auto-detects
  in `datadir` (files starting with "wavelength", "lambda", or "wl_axis").
  Falls back to pixel indices if no file is found.

# Returns
- If `async=true`: Returns a Task
- If `async=false`: Blocks until interrupted
"""
function live_ccd(
        datadir::String;
        file_ext::String=".lvm",
        waittime::Float64=0.1,
        async::Bool=true,
        wavelength_file::Union{String,Nothing}=nothing,
    )
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
        println("Starting live CCD panel in background...")
        println("  Directory: $datadir")
        println("  File extension: $file_ext")

        task = @async _run_live_ccd(datadir, file_ext, waittime, wavelength_file)

        println("  Live CCD panel started! REPL is now available.")
        return task
    else
        _run_live_ccd(datadir, file_ext, waittime, wavelength_file)
        return nothing
    end
end

function _run_live_ccd(datadir, file_ext, waittime, wavelength_file)
    gui = setup_ccd_gui(datadir)

    # Resolve wavelength file: explicit > auto-detect > pixel indices
    wl_file = wavelength_file !== nothing ? wavelength_file : _find_wavelength_file(datadir)
    if wl_file !== nothing && isfile(wl_file)
        wl_vals = load_axis_file(wl_file)
        gui.wl[] = wl_vals
        Makie.update!(gui.hm; arg1=wl_vals)
        gui.ax1.xlabel = AXIS_LABELS.wavelength
        println("  Wavelength file: ", basename(wl_file))
    else
        gui.ax1.xlabel = AXIS_LABELS.pixel_col
        println("  No wavelength file found — using pixel indices")
    end

    try
        watch_and_process_ccd(datadir, file_ext, waittime, gui)
    catch e
        if isa(e, InterruptException)
            println("Live CCD panel interrupted by user")
        else
            println("Unexpected error in live CCD panel: ", e)
            rethrow(e)
        end
    finally
        println("CCD monitoring cleanup completed")
    end
end

"""
    satellite_ccd(raw_data, time_vals, wl_vals, title; dark_theme=true, datadir="")

Static satellite panel for CCD heatmap data. Shows the heatmap with
a diverging RdBu colormap, Colorbar, and mouse-tracked kinetic trace profiler.
Includes Save as PDF and Light/Dark theme toggle buttons.

Axes follow standard TA convention: x = wavelength, y = time.

# Arguments
- `raw_data`: Matrix of ΔA values (raw orientation from load_image, n_time × n_wavelength)
- `time_vals`: Vector of time delay values
- `wl_vals`: Vector of wavelength values
- `title`: Plot title (typically the filename)
- `dark_theme::Bool`: Start with dark theme (default: true)
- `datadir::String`: Data directory path (used for chirp calibration lookup)
- `xlabel::String`: Heatmap x-axis label (default: wavelength). Inherited from live panel.
- `ylabel::String`: Heatmap y-axis label (default: time). Inherited from live panel.
"""
function satellite_ccd(raw_data, time_vals, wl_vals, title::String;
        dark_theme::Bool=true, datadir::String="",
        xlabel::String=AXIS_LABELS.wavelength, ylabel::String=AXIS_LABELS.time_ps)
    colors = dataviewer_colors(dark_theme)

    fig = Figure(size=(800, 900))
    DataInspector(fig)

    # Track theme
    is_dark_theme = Ref(dark_theme)

    # Transpose so x=wavelength, y=time
    oriented = _orient_ccd(raw_data)

    # Data storage — plain Refs
    wl_ref = Ref(collect(Float64, wl_vals))
    time_vec = collect(Float64, time_vals)
    x_idx = Ref(1)

    # Buttons
    save_button = Button(fig, label="Save as PDF")
    wlbutton = Button(fig, label="Load λ axis")
    themebutton = Button(fig, label=dark_theme ? "Light Mode" : "Dark Mode")

    fig[1, 1] = vgrid!(save_button, wlbutton, themebutton;
        tellheight=false, width=150)

    # Heatmap (x=wavelength, y=time)
    max_abs = maximum(abs, oriented)
    cr = max_abs > 0 ? (-max_abs, max_abs) : (-0.01, 0.01)

    ax1 = Axis(fig[1, 2][1, 1],
        title=title,
        xlabel=xlabel,
        ylabel=ylabel,
        xticks=LinearTicks(7),
        yticks=LinearTicks(7))
    hm = heatmap!(ax1, wl_ref[], time_vec, copy(oriented), colormap=:RdBu, colorrange=cr)
    vl = vlines!(ax1, wl_ref[][1], color=:red)
    cb = Colorbar(fig[1, 2][1, 2], hm, label=AXIS_LABELS.delta_a,
        labelcolor=colors[:foreground],
        ticklabelcolor=colors[:foreground],
        tickcolor=colors[:foreground])

    # Cut axis — kinetic trace at selected wavelength
    ax2 = Axis(fig[1, 2][2, 1],
        xlabel=ylabel,
        ylabel=AXIS_LABELS.delta_a,
        xticks=LinearTicks(7),
        yticks=LinearTicks(5),
        yticklabelspace=55.0)
    cut_line = lines!(ax2, [Point2f(0, 0)], color=Makie.to_color(colors[:data]), linewidth=1.5)

    # Apply theme
    fig.scene.backgroundcolor[] = Makie.to_color(colors[:background])
    apply_theme_to_axis!(ax1, colors)
    apply_theme_to_axis!(ax2, colors)

    # Collect elements for theme switching
    all_buttons = [save_button, wlbutton, themebutton]
    plots = [(cut_line, :data)]

    # Mouse tracking — find nearest wavelength on heatmap, update via Makie.update!
    on(events(fig).mouseposition) do mpos
        if is_mouseinside(ax1)
            wl_pos = mouseposition(ax1.scene)[1]
            wl_vec = wl_ref[]
            idx = argmin(abs.(wl_vec .- wl_pos))
            x_idx[] = idx
            Makie.update!(vl; arg1=wl_vec[idx])
            slice = oriented[clamp(idx, 1, size(oriented, 1)), :]
            n = min(length(time_vec), length(slice))
            Makie.update!(cut_line; arg1=[Point2f(time_vec[i], slice[i]) for i in 1:n])
            autolimits!(ax2)
        end
    end

    on(wlbutton.clicks) do _
        wl_file = _find_wavelength_file(datadir)
        if wl_file !== nothing && isfile(wl_file)
            wl_vals = load_axis_file(wl_file)
            wl_ref[] = wl_vals
            Makie.update!(hm; arg1=wl_vals)
            Makie.update!(vl; arg1=wl_vals[clamp(x_idx[], 1, length(wl_vals))])
            ax1.xlabel = AXIS_LABELS.wavelength
            reset_limits!(ax1)
            println("Loaded wavelength axis: ", basename(wl_file))
        else
            println("No wavelength file found in ", datadir)
            println("  Expected: wavelength*.txt, lambda*.txt, or wl_axis*.txt")
        end
    end

    on(save_button.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end
        plotname = to_value(ax1.title)
        save_path = abspath(joinpath(save_folder, plotname * ".pdf"))
        to_save = make_savefig_heatmap(oriented, plotname;
            x=wl_ref[], y=time_vec,
            xlabel=to_value(ax1.xlabel), ylabel=to_value(ax1.ylabel))
        save(save_path, to_save, backend=CairoMakie)
        println("Saved figure to ", save_path)
    end

    on(themebutton.clicks) do _
        is_dark_theme[] = !is_dark_theme[]
        apply_theme!(fig, [ax1, ax2], plots, all_buttons;
            dark=is_dark_theme[], colorbars=[cb])
        themebutton.label = is_dark_theme[] ? "Light Mode" : "Dark Mode"
    end

    return fig
end
