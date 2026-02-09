# Live scan display — subscribes to Observables and shows data point-by-point
#
# QPSDrive pushes data into Observables during a scan.
# This function subscribes to them and displays a growing trace in real time.
# No dependency on QPSDrive — accepts individual Observable kwargs.

"""
    live_scan(; delays, signal, index, status, abort, ...) -> Figure

Display a live scan in progress. The plot grows point-by-point as the scan
engine updates the Observables.

Accepts individual Observables (not ScanObservables) so QPSView does not
depend on QPSDrive. The caller destructures ScanObservables on their side.

# Required Keywords
- `delays::Vector{Float64}` — Full delay axis (fixed at scan start)
- `signal::Observable{Vector{Float64}}` — Signal array, updated each point
- `index::Observable{Int}` — Current scan point (0 = not started)
- `status::Observable{Symbol}` — `:idle`, `:scanning`, `:done`, `:aborted`
- `abort::Ref{Bool}` — Set to `true` to request scan abort

# Optional Keywords
- `description::Observable{String}` — Scan description text
- `progress::Observable{Float64}` — Fraction complete (0.0 to 1.0)
- `dark_theme::Bool` — Start in dark mode (default: true)
"""
function live_scan(;
    delays::Vector{Float64},
    signal::Observable{Vector{Float64}},
    index::Observable{Int},
    status::Observable{Symbol},
    abort::Ref{Bool},
    description::Observable{String} = Observable(""),
    progress::Observable{Float64} = Observable(0.0),
    dark_theme::Bool = true,
)
    GLMakie.activate!()

    colors = dataviewer_colors(dark_theme)

    fig = Figure(size=(700, 500))
    DataInspector(fig)

    # Status label — shows scanning state and progress
    status_text = @lift begin
        s = $status
        p = $progress
        d = $description
        pct = round(Int, p * 100)
        label = isempty(d) ? "" : "  $d"
        if s == :idle
            "Idle$label"
        elseif s == :scanning
            "Scanning... $(pct)%$label"
        elseif s == :done
            "Done$label"
        elseif s == :aborted
            "Aborted at $(pct)%$label"
        else
            string(s)
        end
    end

    # Axis with full x range set immediately
    ax = Axis(fig[1, 1],
        title=status_text,
        xlabel=AXIS_LABELS.time_ps,
        ylabel=AXIS_LABELS.signal,
        xticks=LinearTicks(7),
        yticks=LinearTicks(5),
    )

    # Apply theme
    fig.scene.backgroundcolor[] = Makie.to_color(colors[:background])
    apply_theme_to_axis!(ax, colors)

    # Set x limits to full scan range immediately (y autoscales)
    xlims!(ax, delays[1], delays[end])

    # Growing line — slice x and y to current index
    x_visible = @lift delays[1:max(1, $index)]
    y_visible = @lift $signal[1:max(1, $index)]

    data_line = lines!(ax, x_visible, y_visible, color=Makie.to_color(colors[:data]), linewidth=1.5)

    # Vertical cursor at current delay position
    cursor_x = @lift $index > 0 ? delays[min($index, length(delays))] : delays[1]
    cursor = vlines!(ax, cursor_x, color=Makie.to_color(colors[:accent]), linewidth=1.0, linestyle=:dash)

    # Buttons
    abort_button = Button(fig, label="Abort")
    newfig_button = Button(fig, label="New Figure")
    themebutton = Button(fig, label=dark_theme ? "Light Mode" : "Dark Mode")

    fig[2, 1] = hgrid!(
        abort_button,
        newfig_button,
        themebutton;
        tellwidth=false,
    )

    is_dark_theme = Ref(dark_theme)

    # Theme elements
    all_buttons = [abort_button, newfig_button, themebutton]
    plots = [(data_line, :data), (cursor, :accent)]
    texts = Tuple{Any, Symbol}[]

    # Auto-scale y axis when signal updates
    on(signal) do _
        idx = index[]
        if idx > 1
            y_slice = signal[][1:idx]
            ymin, ymax = extrema(y_slice)
            margin = max(abs(ymax - ymin) * 0.1, 1e-10)
            ylims!(ax, ymin - margin, ymax + margin)
        end
    end

    # Abort button
    on(abort_button.clicks) do _
        abort[] = true
        println("Abort requested")
    end

    # New Figure button — opens scan_satellite with current trace
    on(newfig_button.clicks) do _
        s = status[]
        if s == :done || s == :aborted
            idx = index[]
            trace = QPS.TATrace(delays[1:idx], signal[][1:idx])
            desc = description[]
            t = isempty(desc) ? "Scan" : desc
            newfig = scan_satellite(trace; title=t, dark_theme=is_dark_theme[])
            display(GLMakie.Screen(), newfig)
        else
            println("Scan still running — wait for completion or abort first")
        end
    end

    # Theme toggle
    on(themebutton.clicks) do _
        is_dark_theme[] = !is_dark_theme[]
        apply_theme!(fig, ax, plots, all_buttons; dark=is_dark_theme[], texts=texts)
        themebutton.label = is_dark_theme[] ? "Light Mode" : "Dark Mode"
    end

    return fig
end
