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