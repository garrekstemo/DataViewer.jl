# TODO

## QPS.jl Integration

### Phase 1: Theme Integration
- [x] Add QPS.jl as dependency in Project.toml
- [x] Create `src/themes.jl` with `dataviewer_theme()` for lab monitors
- [x] Integrate theme into `setup_live_plot_gui()`
- [x] Integrate theme into `satellite_panel()`
- [x] Add theme toggle button (dark/light mode)
- [x] Test on actual lab monitor for readability

### Phase 2: Replace Data Loading ✓
- [x] Audit current `load_mir()` return signature
- [x] Create adapter: `load_mir()` wraps `QPS.load_lvm()`
- [x] Refactor `update_plot_data!()` to accept `PumpProbeData`
- [x] Update `satellite_panel()` to work with `PumpProbeData`
- [x] Remove LVM.jl from dependencies
- [x] Update tests for new data structures
- [x] Fix QPS.load_lvm() to handle multiple LVM formats:
  - Chopper ON with time axis
  - Chopper ON with wavelength axis
  - Raw channels (no chopper)
- [x] Remove DataFrames from dependencies - replaced with NamedTuple

### Phase 3: Manual Curve Fitting in Satellite Panel

**Design decision:** Live plot stays minimal (monitoring only). Fitting happens in satellite panel after user snapshots interesting data with "New Fig".

**QPS.jl functions to use (no new fitting code in DataViewer):**
- `QPS.fit_exp_decay(trace)` → returns `ExpDecayIRFFit` with τ, t₀, σ, R²
- `QPS.predict(fit, time)` → returns fitted curve

**Implementation in `satellite_panel()`:**
- [x] Add "Fit" button to satellite panel button grid
- [x] Create `TATrace` from current data for fitting
- [x] On "Fit" click: call `QPS.fit_exp_decay()`, store result
- [x] Add fit line Observable and plot (hidden until fit)
- [x] Display fit parameters (τ, R²) as text annotation
- [x] Handle fit failures gracefully (show message, don't crash)

**Future enhancements (Phase 4):**
- [ ] Biexponential fitting option via `QPS.fit_biexp_decay()`
- [ ] Fit parameter comparison across multiple satellite windows

### Phase 4: Enhanced Satellite Panel
- [ ] Redesign satellite panel for analysis workflow
- [ ] Add signal mode selector (ΔT, ΔA, OD)
- [ ] Add baseline correction options
- [ ] Add multi-exponential fitting
- [ ] Add PDF export with publication theme

---

## Testing
- [x] Create `test/` directory with formal test suite
- [x] Add unit tests for loading functions (LVM, CSV, images)
- [ ] Add integration tests for file watching behavior
- [x] Test error handling with malformed files
- [ ] Add CI workflow for automated testing
- [ ] Add tests for QPS integration (after Phase 2)

## Features
- [ ] File selection menu for historical data review
- [ ] Configurable output directory (currently hardcoded `./plots/`)
- [ ] Logging infrastructure (replace stdout prints)

## Code Quality
- [ ] Consistent variable naming across modules (x/time, y/cut)
- [ ] Add more comprehensive docstrings

## Bugs
- [x] Rename pump-probe LVM test data to be descriptive (renamed to MIRpumpprobe/)
- [x] Live plot shows "differential signal" on single beam data — now detects and shows "Signal"
- [x] "New Figure" button crashes — fixed by initializing y_fit with NaN array
- [x] Don't display "New file" message for files already reported to user — added seen_files tracking
- [x] Don't crash if a file is deleted from the watch folder — added isfile() check
- [x] Fix button panel clipping in satellite panel — added valign = :center
- [x] Light/dark mode toggle should change button colors
- [x] Satellite panel inherits theme from live panel (was always starting dark)
