# QPSView Live Plot Demo

This demo shows the real-time file monitoring and plotting capabilities of QPSView.jl.

## Quick Start

```julia
# Load the demo
include("demo/demo.jl")

# Start the live plot monitor
run_demo()
```

## How it Works

1. **Start Monitoring**: Run `run_demo()` to start watching the `demo/output` folder
2. **Add Files**: Drag CSV files from `demo/device/` into the `demo/output/` folder
3. **Watch Updates**: The plot updates automatically when new files are detected
4. **Stop**: Click the "Stop Monitoring" button in the plot window

## Demo Structure

The demo uses two directories:
- `demo/device/` - Contains CSV test data files (source)
- `demo/output/` - Monitored folder where files are moved to trigger plots

## Available Test Data

The `demo/device/` folder contains various mathematical functions as CSV data:

- `sine.csv` - Sine wave
- `gauss.csv` - Gaussian curve
- `exponential.csv` - Exponential decay
- `damped_sine.csv` - Damped oscillation
- `square.csv` - Square wave
- `arctan.csv` - Arctangent function
- And more!

## Demo Functions

### `demo_live_plot(output_dir)`
Main demo function that starts live monitoring of the specified directory.

### `copy_test_file(test_name, output_dir)`
Helper to copy a specific test file from demo/device/ to demo/output/:
```julia
copy_test_file("sine")  # Copies sine.csv from demo/device/ to demo/output/
```

### `demo_batch_copy(output_dir, delay)`
Automatically copies multiple test files with a delay between each:
```julia
# Run this in a separate terminal/REPL after starting the demo
run_auto_demo()  # Copies files every 2 seconds
```

## Example Workflow

```julia
# Start the monitor (REPL stays available!)
include("demo/demo.jl")
run_demo()

# Now you can use the same REPL to copy files:
copy_test_file("sine")
copy_test_file("gauss")

# Or run automatic demo
run_auto_demo()

# List available files
list_demo_files()
```

The plot updates in real-time and the REPL remains interactive!

---

# CCD Broadband TA Demo

Demonstrates the `live_ccd` heatmap panel using synthetic broadband transient absorption data.

## Quick Start

```julia
include("demo/demo.jl")

# Start the live CCD monitor (generates test data on first run)
run_ccd_demo()

# Copy scan pairs to trigger updates
copy_ccd_pair("scan1")
copy_ccd_pair("scan2")

# Or copy all scans automatically (one every 3 seconds)
run_auto_ccd_demo()
```

## How it Works

1. **Generate Data**: `run_ccd_demo()` creates synthetic CCDABS + T_scale file pairs in `demo/device_ccd/`
2. **Start Monitoring**: Opens a live heatmap panel watching `demo/output_ccd/`
3. **Copy Pairs**: Each scan is a CCDABS + T_scale pair; copying both triggers the heatmap update
4. **Interact**: Hover over the heatmap to see line profiles; click "New Figure" for a static satellite panel

## Test Data

Each synthetic scan has a different decay lifetime and amplitude, simulating sequential acquisitions:

| Scan   | Lifetime (ps) | Amplitude |
|--------|---------------|-----------|
| scan1  | 3.0           | 0.05      |
| scan2  | 5.0           | 0.08      |
| scan3  | 1.5           | 0.03      |
| scan4  | 8.0           | 0.10      |

Spectral features (in pixel space): GSB at pixel ~40, ESA at pixel ~70, SE at pixel ~95.

## Demo Functions

- `run_ccd_demo()` — Start the live CCD monitor
- `run_auto_ccd_demo()` — Auto-copy all scans with 3s delay
- `copy_ccd_pair("scan1")` — Copy a single scan pair
- `list_ccd_scans()` — List available test scans
- `cleanup!("demo/output_ccd")` — Reset the output directory