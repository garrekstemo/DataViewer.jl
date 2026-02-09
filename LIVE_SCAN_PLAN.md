# QPSView Live Scan Monitoring — Implementation Plan

## Overview

Add a `live_scan()` mode to QPSView (QPSView.jl) that displays pump-probe data
**point-by-point in real time** as QPSDrive acquires it. This is fundamentally different
from the existing `live_plot()` which watches for complete files — `live_scan()` subscribes
to Observable streams and updates on every data point.

## Current Architecture

```
live_plot() flow:

  FileWatching.watch_folder(dir)
       │
       ▼
  File appears → load_function(filepath) → (x, y, xlabel, ylabel, title, data)
       │
       ▼
  update_plot_data!(x_obs, y_obs, ...) → Makie redraws entire trace
```

- Data arrives as **complete files** — x and y arrays are fully populated
- `Observable`s are replaced wholesale (`x.val = new_x; notify(x)`)
- Satellite panel gives post-hoc analysis (fit, peak find)

## New Architecture

```
live_scan() flow:

  QPSDrive scan engine
       │
       ├─── signal::Observable{Vector{Float64}}  (grows point by point)
       ├─── index::Observable{Int}               (current scan position)
       └─── status::Observable{Symbol}           (:idle, :scanning, :done, :aborted)
       │
       ▼
  QPSView subscribes to Observables → Makie redraws incrementally
```

- Data arrives **one point at a time**
- `Observable`s are mutated in place (`signal[][i] = value; notify(signal)`)
- Plot updates after each point — user sees trace build up live
- Abort, progress, and status shown in GUI

## Interface Contract (QPSDrive → QPSView)

QPSDrive exports a `ScanObservables` struct that QPSView subscribes to:

```julia
# Defined in QPSDrive (or a shared lightweight package)
struct ScanObservables
    delays::Vector{Float64}                  # Fixed: time delay axis (ps)
    signal::Observable{Vector{Float64}}      # Updated each point
    index::Observable{Int}                   # Current point index (0 = not started)
    status::Observable{Symbol}               # :idle, :scanning, :done, :aborted
    abort::Ref{Bool}                         # Set true to request abort
    description::Observable{String}          # Scan description text
    progress::Observable{Float64}            # 0.0 to 1.0
end
```

QPSDrive's scan engine updates these during `run_scan()`:

```julia
function run_scan(scan::KineticScan; observables=nothing, ...)
    obs = something(observables, ScanObservables(scan.delays))
    obs.status[] = :scanning

    for (i, delay) in enumerate(scan.delays)
        obs.abort[] && break

        move_to_delay!(scan.stage, delay)
        sleep(scan.settle_time)
        obs.signal[][i] = read_averaged(scan.detector, scan.averages)
        obs.index[] = i
        obs.progress[] = i / length(scan.delays)
        notify(obs.signal)
    end

    obs.status[] = obs.abort[] ? :aborted : :done
    return ScanResult(...)
end
```

## QPSView Implementation

### New file: `src/live_scan.jl`

#### 1. Main entry point

```julia
function live_scan(observables::ScanObservables;
    dark_theme::Bool = true,
    show_residuals::Bool = false
) -> Figure
```

Creates a GLMakie window that:
- Plots `delays` vs `signal` as a line that extends point-by-point
- Shows a vertical cursor at the current delay position
- Displays progress bar and status
- Has an Abort button
- Has a "New Figure" button (opens satellite panel when scan is done)

#### 2. GUI layout

```
┌─────────────────────────────────────────────────────┐
│  [Status: Scanning ●]        [Progress: ████░░ 67%] │
│  Description: ESA kinetics, 2050 cm⁻¹               │
├─────────────────────────────────────────────────────┤
│                                                     │
│     ╭─signal line (grows left to right)             │
│     │    ╷                                          │
│     │    │← vertical cursor (current position)      │
│     │    ╷                                          │
│  ΔA │   ╰─────────────────────── (future: gray)    │
│     │                                               │
│     └───────────────────────────────────────────── │
│              Time delay (ps)                        │
├─────────────────────────────────────────────────────┤
│  [Abort]  [New Figure]  [Save]  [Light/Dark Mode]   │
└─────────────────────────────────────────────────────┘
```

#### 3. Observable subscriptions

```julia
function setup_scan_gui(obs::ScanObservables; dark_theme=true)
    colors = dataviewer_colors(dark_theme)

    fig = Figure(size=(700, 500))
    ax = Axis(fig[2, 1],
        xlabel = "Time delay (ps)",
        ylabel = "ΔA"
    )

    # Full x-axis shown from the start (scan range is known)
    delays = obs.delays

    # Signal line — only draw up to current index
    # Use @lift to create a derived observable that slices the data
    x_visible = @lift(delays[1:max(1, $obs.index)])
    y_visible = @lift(obs.signal[][1:max(1, $obs.index)])
    lines!(ax, x_visible, y_visible, color=colors[:data])

    # Vertical cursor at current position
    cursor_x = @lift([$obs.index > 0 ? delays[$obs.index] : delays[1]])
    vlines!(ax, cursor_x, color=colors[:accent], linestyle=:dash)

    # Status bar (top)
    status_text = @lift begin
        s = $obs.status
        p = round(Int, $obs.progress * 100)
        s == :scanning ? "Scanning... $(p)%" :
        s == :done     ? "Scan complete" :
        s == :aborted  ? "Aborted at $(p)%" :
                         "Idle"
    end
    Label(fig[1, 1], status_text, fontsize=14, halign=:left)

    # Description
    Label(fig[1, 1], obs.description, fontsize=12, halign=:right,
        color=colors[:foreground])

    # Buttons
    abort_btn = Button(fig, label="Abort", buttoncolor=:red)
    newfig_btn = Button(fig, label="New Figure")
    save_btn = Button(fig, label="Save")
    theme_btn = Button(fig, label=dark_theme ? "Light Mode" : "Dark Mode")

    fig[3, 1] = hgrid!(abort_btn, newfig_btn, save_btn, theme_btn;
        tellwidth=false)

    # Abort callback
    on(abort_btn.clicks) do _
        obs.abort[] = true
    end

    # Auto-scale y as data comes in
    on(obs.signal) do _
        autolimits!(ax)
    end

    # Set x limits to full scan range immediately
    xlims!(ax, extrema(delays))

    # On completion, enable analysis
    on(obs.status) do s
        if s == :done || s == :aborted
            # Enable "New Figure" → opens satellite panel with full data
        end
    end

    return fig
end
```

#### 4. Integration with existing satellite panel

When the scan completes, "New Figure" opens the existing `satellite_panel()` with the
completed trace as a `TATrace`. The satellite panel already handles kinetic fitting
(`do_fit!`) and peak detection — no changes needed there.

```julia
on(newfig_btn.clicks) do _
    if obs.status[] in (:done, :aborted)
        n = obs.index[]
        trace = QPSTools.TATrace(delays[1:n], obs.signal[][1:n])
        # Reuse existing satellite_panel infrastructure
        newfig = satellite_panel_from_trace(trace, dark_theme=is_dark_theme[])
        display(GLMakie.Screen(), newfig)
    end
end
```

### New file: `src/scan_satellite.jl` (optional)

A simplified satellite panel that takes a `TATrace` directly instead of raw data.
Could reuse much of the existing `satellite_panel` logic, or be a thin wrapper
that converts `TATrace` → the 6-tuple format satellite_panel expects.

## Implementation Steps

### Phase 1: Observable protocol (in QPSDrive)

1. Define `ScanObservables` struct
2. Have `run_scan()` accept and update `ScanObservables`
3. Test with a mock scan (no hardware) that populates Observables on a timer

### Phase 2: Basic live_scan display (in QPSView)

4. Add `src/live_scan.jl` with `live_scan(obs::ScanObservables)`
5. Implement growing line plot with cursor
6. Implement Abort button → sets `obs.abort[] = true`
7. Implement status/progress display
8. Test with mock scan from Phase 1

### Phase 3: Post-scan analysis integration

9.  "New Figure" button → open satellite panel with completed TATrace
10. "Save" button → save current state as PDF via CairoMakie
11. Auto-save scan data on completion (CSV or LVM format)

### Phase 4: Polish

12. Theme switching (reuse existing `apply_theme!` infrastructure)
13. Scan history (if multiple scans in one session)
14. Multi-trace overlay (running scan vs previous scan for comparison)

## Dependency Considerations

- QPSView currently depends on QPSTools (renamed from QPS)
- QPSView would also need to depend on QPSDrive (for ScanObservables type)
- **Alternative**: Define ScanObservables in a tiny shared package, or just use
  plain Observables (no struct dependency) and pass them as keyword arguments:

```julia
# No QPSDrive dependency needed — just Observables from Makie
live_scan(;
    delays::Vector{Float64},
    signal::Observable{Vector{Float64}},
    index::Observable{Int},
    status::Observable{Symbol},
    abort::Ref{Bool},
)
```

This keeps QPSView and QPSDrive loosely coupled — they communicate through
Observables without needing to import each other.

## Existing Code to Reuse

| Existing | Reuse for live_scan |
|----------|---------------------|
| `dataviewer_theme()`, `dataviewer_colors()` | Theme system |
| `apply_theme!()`, `apply_theme_to_axis!()` | Theme switching |
| `satellite_panel()` | Post-scan analysis (fit, peak detect) |
| `make_savefig()` | PDF export |
| `_is_spectral_data()` | Not needed (scan is always kinetics) |
| `_extract_data()` | Not needed (data comes as Observables) |
| `AXIS_LABELS` | Reuse time-axis labels |

## Open Questions

1. **Multi-channel scans**: If the MFLI provides R, X, Y, theta simultaneously,
   should live_scan show multiple channels? Or just the primary signal?

2. **Averaging display**: Show individual shots vs running average? The MFLI
   handles averaging internally, but showing noise level could be useful.

3. **Repeated scans**: If a student runs the same scan 5 times for statistics,
   should live_scan overlay all traces or replace each time?

4. **QPSView package rename**: QPSView.jl → QPSView.jl should happen
   before or alongside this work to keep the ecosystem names consistent.
