# QPSView themes for lab monitor conditions
# Designed for: low-quality monitors, windowless rooms, fluorescent lighting

#==============================================================================#
# COLOR PALETTES
#==============================================================================#

"""
    dataviewer_colors(dark::Bool=true)

Color palette optimized for visibility on low-quality lab monitors.
High contrast, colorblind-friendly, distinguishable under fluorescent lights.

Returns a Dict with keys:
- `:background`, `:foreground` - Base colors
- `:data`, `:fit`, `:data_alt` - Plot colors
- `:pump_on`, `:pump_off`, `:diff` - Pump-probe signals
- `:accent`, `:warning`, `:error` - Status indicators
- `:grid` - Grid lines
- `:btn_bg`, `:btn_fg` - Button colors
"""
function dataviewer_colors(dark::Bool=true)
    if dark
        return Dict(
            :background => "#1a1a2e",    # Dark blue-gray (easier than pure black)
            :foreground => "#eaeaea",    # Off-white (less harsh than pure white)
            :data => "#ff6b6b",          # Coral red (high visibility)
            :fit => "#4ecdc4",           # Teal (distinct from data)
            :data_alt => "#ffd93d",      # Yellow (for secondary data)
            :grid => "#2d2d44",          # Subtle grid
            :accent => "#6bcb77",        # Green (for good fit indicators)
            :warning => "#ff9f43",       # Orange (for warnings)
            :error => "#ee5a5a",         # Red (for errors/poor fits)
            :pump_on => "#ff6b6b",       # Red for pump-on signal
            :pump_off => "#4ecdc4",      # Teal for pump-off signal
            :diff => "#ffd93d",          # Yellow for difference signal
            :btn_bg => "#404040",        # Button background
            :btn_fg => "#e0e0e0",        # Button text
        )
    else
        return Dict(
            :background => "#f5f5f5",    # Light gray
            :foreground => "#202020",    # Near black
            :data => "#c0392b",          # Dark red
            :fit => "#16a085",           # Dark teal
            :data_alt => "#d35400",      # Dark orange
            :grid => "#cccccc",          # Light grid
            :accent => "#27ae60",        # Green
            :warning => "#e67e22",       # Orange
            :error => "#c0392b",         # Red
            :pump_on => "#e74c3c",       # Red for pump-on
            :pump_off => "#27ae60",      # Green for pump-off
            :diff => "#c0392b",          # Dark red for difference
            :btn_bg => "#e0e0e0",        # Button background
            :btn_fg => "#202020",        # Button text
        )
    end
end

# Legacy aliases for backwards compatibility
dataviewer_light_colors() = dataviewer_colors(false)

#==============================================================================#
# RUNTIME THEME APPLICATION
#==============================================================================#

"""
    apply_theme!(fig, ax, plots, buttons; dark=true, legend=nothing, texts=[])

Apply theme to all GUI elements at runtime. Call this when toggling themes.

Uses `Makie.update!()` for plot objects (atomic updates) and direct/Observable
assignment for Blocks (Axis, Button, Legend).

# Arguments
- `fig`: The Figure
- `ax`: The Axis (or Vector of Axes)
- `plots`: Vector of `(plot_object, color_key)` pairs
- `buttons`: Vector of Button objects
- `dark`: Whether to use dark theme (default: true)
- `legend`: Optional Legend object (or Vector)
- `texts`: Optional Vector of `(text_plot, color_key)` pairs
"""
function apply_theme!(fig, ax, plots, buttons; dark::Bool=true, legend=nothing, texts=[], colorbars=[])
    colors = dataviewer_colors(dark)

    # Figure background
    fig.scene.backgroundcolor[] = Makie.to_color(colors[:background])

    # Axis/Axes - direct assignment
    axes = ax isa Vector ? ax : [ax]
    for a in axes
        apply_theme_to_axis!(a, colors)
    end

    # Plot objects - use Makie.update!() for atomic updates
    for (plot, color_key) in plots
        Makie.update!(plot; color = Makie.to_color(colors[color_key]))
    end

    # Text objects
    for (text_plot, color_key) in texts
        Makie.update!(text_plot; color = Makie.to_color(colors[color_key]))
    end

    # Buttons - Observable assignment
    for btn in buttons
        btn.buttoncolor[] = Makie.to_color(colors[:btn_bg])
        btn.labelcolor[] = Makie.to_color(colors[:btn_fg])
    end

    # Colorbars - direct assignment
    for cb in colorbars
        cb.labelcolor = colors[:foreground]
        cb.ticklabelcolor = colors[:foreground]
        cb.tickcolor = colors[:foreground]
    end

    # Legend(s) - Observable assignment
    if legend !== nothing
        legends = legend isa Vector ? legend : [legend]
        for leg in legends
            bg = Makie.to_color(colors[:background])
            leg.backgroundcolor[] = Makie.RGBAf(bg.r, bg.g, bg.b, 0.8f0)
            leg.labelcolor[] = Makie.to_color(colors[:foreground])
            leg.framecolor[] = Makie.to_color(colors[:foreground])
        end
    end

    return colors
end

"""
    apply_theme_to_axis!(ax, colors)

Apply theme colors to a single Axis. Internal helper for `apply_theme!`.
"""
function apply_theme_to_axis!(ax, colors)
    ax.backgroundcolor = colors[:background]
    for prop in (:xlabelcolor, :ylabelcolor, :titlecolor,
                 :xticklabelcolor, :yticklabelcolor,
                 :xtickcolor, :ytickcolor,
                 :bottomspinecolor, :leftspinecolor,
                 :topspinecolor, :rightspinecolor)
        setproperty!(ax, prop, colors[:foreground])
    end
end

#==============================================================================#
# MENU STYLING
#==============================================================================#

_menu_hover_color(bg, fg, t=0.25f0) =
    Makie.RGBAf(bg.r + t*(fg.r - bg.r), bg.g + t*(fg.g - bg.g), bg.b + t*(fg.b - bg.b), 1.0f0)

function _style_menu!(menu, colors)
    bg = Makie.to_color(colors[:btn_bg])
    fg = Makie.to_color(colors[:foreground])
    menu.textcolor = fg
    menu.cell_color_inactive_even = bg
    menu.cell_color_inactive_odd = bg
    menu.cell_color_hover = _menu_hover_color(bg, fg)
    menu.cell_color_active = Makie.to_color(colors[:accent])
    menu.selection_cell_color_inactive = bg
    menu.dropdown_arrow_color = fg
    # Makie Menu doesn't reactively bind selection_cell_color_inactive to its
    # polygon — poke the poly directly so the color applies immediately.
    menu.blockscene.plots[1].color = bg
    # Makie Menu doesn't bind dropdown text to textcolor — fix manually.
    for child in menu.blockscene.children
        for plot in child.plots
            if plot isa Makie.Text
                plot.color = fg
            end
        end
    end
end

#==============================================================================#
# MAKIE THEMES (for new figures)
#==============================================================================#

"""
    dataviewer_theme(dark::Bool=true)

High-contrast theme for lab monitors. Optimized for:
- Low-resolution displays
- Fluorescent lighting (reduces glare)
- Quick visual assessment during experiments
- Readable from 1-2 meters away

Use with: `set_theme!(dataviewer_theme())`
"""
function dataviewer_theme(dark::Bool=true)
    colors = dataviewer_colors(dark)

    return Theme(
        # Figure
        figure_padding = 20,
        backgroundcolor = colors[:background],

        # Fonts - large for readability
        fontsize = 18,

        # Axis
        Axis = (
            backgroundcolor = colors[:background],
            xgridcolor = colors[:grid],
            ygridcolor = colors[:grid],
            xgridwidth = 1,
            ygridwidth = 1,
            xgridvisible = false,
            ygridvisible = false,

            # Spines
            topspinevisible = false,
            rightspinevisible = false,
            leftspinecolor = colors[:foreground],
            bottomspinecolor = colors[:foreground],
            spinewidth = 2,

            # Ticks
            xtickcolor = colors[:foreground],
            ytickcolor = colors[:foreground],
            xtickwidth = 2,
            ytickwidth = 2,
            xticksize = 8,
            yticksize = 8,
            xticklabelcolor = colors[:foreground],
            yticklabelcolor = colors[:foreground],
            xticklabelsize = 16,
            yticklabelsize = 16,

            # Labels
            xlabelcolor = colors[:foreground],
            ylabelcolor = colors[:foreground],
            xlabelsize = 18,
            ylabelsize = 18,
            xlabelpadding = 10,
            ylabelpadding = 10,

            # Title
            titlecolor = colors[:foreground],
            titlesize = 20,
            titlegap = 12,
        ),

        # Lines - thick for visibility
        Lines = (
            linewidth = 1.5,
            color = colors[:data],
        ),

        # Scatter
        Scatter = (
            markersize = 10,
            color = colors[:data],
        ),

        # Legend — use to_color() so Observable is RGBA-typed from the start
        Legend = (
            backgroundcolor = Makie.RGBAf(Makie.to_color(colors[:background]), 0.8f0),
            framecolor = Makie.to_color(colors[:grid]),
            labelcolor = Makie.to_color(colors[:foreground]),
            titlecolor = Makie.to_color(colors[:foreground]),
            labelsize = 14,
            titlesize = 16,
        ),

        # Colorbar
        Colorbar = (
            labelcolor = colors[:foreground],
            ticklabelcolor = colors[:foreground],
            tickcolor = colors[:foreground],
        ),

        # Text
        Text = (
            color = colors[:foreground],
            fontsize = 16,
        ),

        # Button (for GUI)
        Button = (
            buttoncolor = colors[:btn_bg],
            labelcolor = colors[:foreground],
            cornerradius = 4,
        ),
    )
end

# Legacy alias
dataviewer_light_theme() = dataviewer_theme(false)
