# Simplified satellite panel for post-scan analysis
#
# Takes a TATrace directly (from a completed scan) rather than loading
# from file. Provides fitting, save, and theme toggle — no file history,
# pump on/off, or peak detection (kinetics only).

"""
    scan_satellite(trace::QPS.TATrace; title="Scan", dark_theme=true) -> Figure

Open a satellite panel for analyzing a completed scan trace.

Provides:
- Data line plot
- Exponential decay fitting with adjustable t₀
- Save as PDF
- Light/dark theme toggle
"""
function scan_satellite(trace::QPS.TATrace; title::String="Scan", dark_theme::Bool=true)
    colors = dataviewer_colors(dark_theme)

    fig = Figure(size=(700, 500))
    DataInspector(fig)

    x_data = trace.time
    y_data = trace.signal

    # Observables
    x = Observable(copy(x_data))
    y = Observable(copy(y_data))
    y_fit = Observable(fill(NaN, length(x_data)))
    fit_result = Ref{Union{Nothing, QPS.ExpDecayFit}}(nothing)
    is_dark_theme = Ref(dark_theme)

    # Widgets
    save_button = Button(fig, label="Save as PDF")
    themebutton = Button(fig, label=dark_theme ? "Light Mode" : "Dark Mode")
    fitbutton = Button(fig, label="Fit")
    t0_label = Label(fig, "t₀ (ps):", fontsize=14, color=colors[:foreground])
    t0_box = Textbox(fig, stored_string="1.0", width=80,
        textcolor=colors[:foreground],
        boxcolor=colors[:background],
        bordercolor=colors[:foreground])

    # Layout: button column on left
    fig[1, 1] = vgrid!(
        save_button,
        themebutton,
        t0_label,
        t0_box,
        fitbutton;
        tellheight=false,
        width=180
    )

    ax = Axis(fig[1, 2],
        title=title,
        xlabel=AXIS_LABELS.time_ps,
        ylabel=AXIS_LABELS.signal,
        xticks=LinearTicks(7),
        yticks=LinearTicks(5),
    )

    # Apply theme
    fig.scene.backgroundcolor[] = Makie.to_color(colors[:background])
    apply_theme_to_axis!(ax, colors)

    # Plot elements
    data_line = lines!(ax, x, y, color=Makie.to_color(colors[:data]), linewidth=1.5)
    fit_line = lines!(ax, x, y_fit, color=Makie.to_color(colors[:fit]), linewidth=1.5, visible=false)
    fit_text = text!(ax, 0.98, 0.5, text="", space=:relative, align=(:right, :center),
        color=Makie.to_color(colors[:foreground]), fontsize=14, visible=false)

    # Theme elements
    all_buttons = [save_button, themebutton, fitbutton]
    plots = [(data_line, :data), (fit_line, :fit)]
    texts = [(fit_text, :foreground)]

    # Fitting
    function do_fit!()
        x_vals = to_value(x)
        y_vals = to_value(y)

        t_peak = QPS.find_peak_time(x_vals, y_vals)
        t0_str = t0_box.displayed_string[]
        t_start = something(tryparse(Float64, t0_str), max(t_peak, 1.0))
        t0_box.displayed_string = string(round(t_start, digits=2))

        trace_for_fit = QPS.TATrace(x_vals, y_vals)
        result = QPS.fit_exp_decay(trace_for_fit; irf=false, t_start=t_start)
        fit_result[] = result

        y_predicted = fill(NaN, length(x_vals))
        fit_mask = x_vals .>= t_start
        y_predicted[fit_mask] = QPS.predict(result, x_vals[fit_mask])
        y_fit[] = y_predicted

        τ_str = round(result.tau, digits=2)
        r2_str = round(result.rsquared, digits=4)
        fit_text.text = "τ = $(τ_str) ps\nR² = $(r2_str)"

        Makie.update!(fit_line; visible=true)
        Makie.update!(fit_text; visible=true)

        println("Fit: τ = $(τ_str) ps, R² = $(r2_str) (fit from $(round(t_start, digits=2)) ps)")
        return result
    end

    function try_fit!()
        try
            do_fit!()
        catch e
            println("Fit failed: ", e)
            Makie.update!(fit_line; visible=false)
            Makie.update!(fit_text; visible=false)
        end
    end

    on(fitbutton.clicks) do _
        try_fit!()
    end

    on(t0_box.stored_string) do _
        try_fit!()
    end

    on(save_button.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end

        plotname = to_value(ax.title)
        save_path = abspath(joinpath(save_folder, plotname * ".pdf"))
        to_save = make_savefig(x, y, plotname, to_value(ax.xlabel), to_value(ax.ylabel))
        save(save_path, to_save, backend=CairoMakie)
        println("Saved figure to ", save_path)
    end

    on(themebutton.clicks) do _
        is_dark_theme[] = !is_dark_theme[]
        new_colors = apply_theme!(fig, ax, plots, all_buttons; dark=is_dark_theme[], texts=texts)
        themebutton.label = is_dark_theme[] ? "Light Mode" : "Dark Mode"
        t0_label.color = new_colors[:foreground]
        t0_box.textcolor = new_colors[:foreground]
        t0_box.boxcolor = new_colors[:background]
        t0_box.bordercolor = new_colors[:foreground]
    end

    return fig
end
