# QPSView.jl

Real-time data visualization for experimental devices that continuously save measurements to files. Monitors directories for new data and displays them with interactive GLMakie plots.

## Architecture

```
src/
├── QPSView.jl        # Module entry point, exports public API
├── themes.jl            # Lab monitor themes (dark/light, high contrast)
├── live_plot.jl         # Main 1D plotting (async file watching, GUI controls)
├── live_image.jl        # 2D heatmap visualization with line profiler
├── live_ccd.jl          # CCD ΔA heatmap with diverging colormap + line profiler
├── loading_functions.jl # Data loaders (LVM, CSV, images)
└── common_functions.jl  # Shared utilities

docs/
└── qps_integration_plan.md  # Phased plan for QPS.jl integration
```

## Key Patterns

### Async File Monitoring
- `live_plot()` returns a `Task` by default (non-blocking)
- Use `blocking=true` for sequential execution
- Stop signal via `Channel{Bool}` enables graceful shutdown
- Start/Stop buttons allow restart without creating new figures
- File watcher tracks seen filenames in `_watcher_registry` (keyed by normalized dir path)
- `seen_files` is only populated after confirming the file exists (`isfile` check), so deletion events from `cleanup!` don't re-pollute the set

### cleanup!

Reset the monitored directory and watcher history from the REPL:
```julia
task = live_plot("output/")
# ... later ...
cleanup!("output")   # trailing slash doesn't matter
```

- Deletes all files (not subdirectories) in the given directory
- Clears the watcher's `seen_files` set so re-added files are detected
- All directory paths are normalized via `_normdir()` (strips trailing slashes after `abspath`), so `"output/"` and `"output"` always match the same registry key

### Observable Updates
Atomic updates prevent race conditions:
```julia
x_obs.val = new_x
y_obs.val = new_y
notify(x_obs)  # Single notification after all updates
```

### Data Loading
Primary format is **LVM (LabView)**. The `load_mir()` function:
- Auto-detects wavelength vs time axis
- Handles differential signal data (pump on/off)
- Returns `nothing` for empty/bad files (caller must handle)

## Development Commands

```bash
# Run demo
julia --project -e 'using QPSView; run_demo()'

# Auto demo (copies test files automatically)
julia --project -e 'using QPSView; run_auto_demo()'
```

## Themes

Lab monitor theme optimized for windowless rooms with fluorescent lighting:
```julia
set_theme!(dataviewer_theme())       # Dark, high-contrast (auto-applied in GUI)
set_theme!(dataviewer_light_theme()) # Light variant
```

Color palette via `dataviewer_colors()`:
- `:data` (coral red) / `:fit` (teal) - primary plot colors
- `:pump_on` / `:pump_off` / `:diff` - pump-probe signals
- `:accent` (green) / `:warning` (orange) / `:error` (red) - status indicators

## Satellite Panel

The satellite panel opens via the "New Figure" button on the live plot. Layout:
- **Left column** (`fig[1, 1]`): button panel in a `vgrid!` with fixed `width = 150`
- **Right column** (`fig[1, 2]`): Axis with data
- Widget order: File history Menu, Change x units, Flip y-axis, Save as PDF, Light Mode, t₀ label, t₀ textbox, Fit

### File history Menu
A `Menu` dropdown at the top of the button column lists all files matching `file_ext` in `datadir`. Selecting a file reloads the plot data, resets fit state, and updates axis labels. The file list is static (scanned once at panel creation). Pump on/off data uses `Observable` wrappers (`on_obs`, `off_obs`) with derived `@lift(-$obs)` so pump lines update reactively on file reload.

### Element positioning
- **Fit text**: middle-right (`0.98, 0.5`, align right-center) — avoids both the peak and tail of exponential decays
- **Legend**: right-bottom (`:rb`) — left-side positions overflow into the button panel column

### Fit interaction with other controls
- **Signal toggle** (pump on/off): hides fit line and fit text, since the fit only applies to the difference signal
- **Flip y-axis**: negates `y_fit` along with `y` so the fit curve follows the data

## Kinetics Fitting

The satellite panel's "Fit" button runs `QPS.fit_exp_decay` on the displayed trace. The fit window starts at **max(peak time, 1.0 ps)** to skip the instrument response function (IRF). Key design decisions:

- **No data shifting.** The raw time axis is never modified — the start time only controls which region is passed to the fitter. This preserves the original delay-stage positions so users can diagnose stage alignment issues.
- **Fit line visibility.** The fit curve is drawn only in the fitted region (NaN elsewhere), so it doesn't visually extend into the pre-pulse baseline.
- **Spectral data.** Fitting is disabled when the x-axis is wavelength or wavenumber — spectral lineshapes require model selection better suited for desk analysis.

### User-adjustable t₀

The t₀ textbox lets the user set the fit start time. Two ways to trigger a fit:
1. Type a value and click **Fit**
2. Type a value and press **Enter**

Implementation notes:
- `do_fit!()` reads `t0_box.displayed_string[]` (live text) so Enter is not required before clicking Fit
- Pressing Enter fires `t0_box.stored_string`, which triggers `try_fit!()` via an `on` callback
- After fitting, `do_fit!()` writes the actual t₀ used back to `t0_box.displayed_string` (not `stored_string`) to avoid re-triggering the callback
- Invalid textbox input falls back to `max(peak, 1.0)` ps via `tryparse`

## Live CCD Panel

`live_ccd(datadir; wavelength_file=nothing)` monitors a directory for CCDABS + T_scale file pairs and displays ΔA heatmaps with a diverging `:RdBu` colormap centered at zero. Axes follow standard TA convention: x = wavelength (nm), y = time (ps). Wavelength file is auto-detected or can be specified explicitly; falls back to pixel indices.

### Layout
- **Top**: Heatmap axis (wavelength × time) with Colorbar ("ΔA")
- **Middle**: Kinetic trace profiler (ΔA vs time at mouse wavelength)
- **Bottom**: Button row (New Figure, Light Mode)

### File watching
- Uses `_watcher_registry` for `cleanup!` compatibility
- Pair deduplication via composite key (`"CCDABS_file+T_scale_file"`) in `seen_files`
- `isfile` check before processing (handles cleanup deletion events)
- T_scale values loaded via `load_axis_file` and used for time axis
- Wavelength file auto-detected via `_find_wavelength_file` (looks for files starting with "wavelength", "lambda", "wl_axis")
- Falls back to pixel indices if no wavelength file found

### Axis convention
Standard TA convention: **x = wavelength (nm), y = time (ps)**. Raw data `(n_time, n_wavelength)` is transposed via `_orient_ccd` so the heatmap first index maps to x (wavelength). Line profiler shows kinetic trace (ΔA vs time) at mouse wavelength position.

### Satellite panel
`satellite_ccd(raw_data, time_vals, wl_vals, title)` opens a static panel with:
- Button column (width=150) on the left: Save as PDF, Light/Dark toggle
- Heatmap + Colorbar + kinetic trace profiler on the right
- PDF export via `make_savefig_heatmap` with x/y vectors (CairoMakie backend)
- `raw_ref` in live panel stores untransposed data for satellite handoff

## QPS.jl Integration (In Progress)

Integrating with lab-wide QPS.jl package. See `docs/qps_integration_plan.md`.

**Goals:**
1. Remove DataFrames and LVM.jl deps → use `QPS.PumpProbeData`
2. Add automatic curve fitting on file load
3. Unified theming with other lab tools

**Phases:** Theme → Data loading → Auto-fitting → Enhanced analysis

## Debugging Approach

When diagnosing layout or behavioral issues:
1. **Trace before fixing** - Identify the specific element causing the problem before suggesting solutions
2. **Prefer subtractive fixes** - Removing or disabling behavior (e.g., `tellwidth=false`) often reveals the root cause better than adding compensating code
3. **Follow the evidence** - When a change makes things worse, that's diagnostic information pointing toward the real culprit
4. **Minimal fixes first** - A one-line attribute change that addresses root cause beats a multi-line workaround

### Makie Layout Debugging

Use transparent `Box()` elements to visualize how grid cells are sized:
```julia
Box(fig[1, 1], color = (:yellow, 0.2), strokewidth = 0)
Box(fig[1, 2], color = (:red, 0.2), strokewidth = 0)
```

Common layout issues: elements with `tellwidth=true` (default) report their width to the parent GridLayout, which can unexpectedly constrain other columns.

## Julia 1.12 World Age Warnings

Julia 1.12 introduced stricter world age semantics. Watch for this warning:

```
WARNING: Detected access to binding `Module.function` in a world prior to its definition world.
  Julia 1.12 has introduced more strict world age semantics for global bindings.
  !!! This code may malfunction under Revise.
  !!! This code will error in future versions of Julia.
```

**This is new in Julia 1.12 and may not be in training data.** Test with `julia --depwarn=error` to get stack traces.

**Proper fixes** (don't just use `invokelatest` as a bandaid):
- Fix module `include()` order so functions are defined before use
- Avoid storing functions in globals accessed before definition
- Move function calls out of module-level code into functions
- Restructure to avoid dynamic dispatch at load time

