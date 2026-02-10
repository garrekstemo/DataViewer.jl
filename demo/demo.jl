using QPSView
using Random

"""
    demo_live_plot(output_dir=nothing)

Demonstrates the live plotting functionality using CSV test data.
Drag CSV files from demo/device/ into demo/output/ to see live updates.

# Usage
1. Run this function to start monitoring demo/output/
2. Drag CSV files from demo/device/ into demo/output/ folder
3. Watch the plot update in real time!
4. Click "Stop Monitoring" when done
"""
function demo_live_plot(output_dir=nothing)
    # Find project root and set monitoring directory
    if output_dir === nothing
        # Find the project root (where QPSView.jl package is)
        current_dir = pwd()
        project_root = current_dir

        # If we're in demo folder, go up one level
        if endswith(current_dir, "demo") || endswith(current_dir, "demo/")
            project_root = dirname(current_dir)
        end

        output_dir = joinpath(project_root, "demo", "output")
    end
    # Create output directory if it doesn't exist
    if !isdir(output_dir)
        mkpath(output_dir)  # Creates nested directories if needed
        println("Created output directory: $output_dir")
    end

    println("=== QPSView Live Plot Demo ===")
    println("1. Drag CSV files from demo/device/ into: $output_dir")
    println("2. Watch the plot update automatically!")
    println("3. Available test files:")

    # Show available test files from demo/device
    test_dir = joinpath(dirname(output_dir), "device")
    if isdir(test_dir)
        test_files = filter(f -> endswith(f, ".csv"), readdir(test_dir))
        for (i, filename) in enumerate(test_files)
            println("   $i. $filename")
        end
    else
        println("   Test data directory not found: $test_dir")
        println("   Please ensure demo/device/ exists with CSV files")
    end

    println("\n4. Starting live plot monitor...")
    println("5. Click 'Stop Monitoring' button to exit")
    println("6. REPL remains available for running copy_test_file() or run_auto_demo()\n")

    # Start the live plot with CSV loading function (async by default)
    task = live_plot(output_dir, load_test_data, ".csv"; waittime=0.5)

    println("✓ Demo started! REPL is now available.")
    println("  Try: copy_test_file(\"sine\") or run_auto_demo()")

    return task  # Return the task so users can manage it if needed
end

"""
    copy_test_file(test_name::String, output_dir=nothing)

Helper function to copy a test file from demo/device/ to demo/output/ for testing.
"""
function copy_test_file(test_name::String, output_dir=nothing)
    # Set default output directory relative to project root
    if output_dir === nothing
        current_dir = pwd()
        project_root = endswith(current_dir, "demo") ? dirname(current_dir) : current_dir
        output_dir = joinpath(project_root, "demo", "output")
    end

    # Find source file in demo/device
    project_root = endswith(pwd(), "demo") ? dirname(pwd()) : pwd()
    source_file = joinpath(project_root, "demo", "device", "$(test_name).csv")

    if !isfile(source_file)
        println("Test file not found: $source_file")
        println("Available files in demo/device/:")
        test_dir = joinpath(project_root, "demo", "device")
        if isdir(test_dir)
            csv_files = filter(f -> endswith(f, ".csv"), readdir(test_dir))
            for file in csv_files
                name_without_ext = replace(file, ".csv" => "")
                println("  - $name_without_ext")
            end
        else
            println("  demo/device/ directory not found!")
        end
        return
    end

    if !isdir(output_dir)
        mkpath(output_dir)
    end

    dest_file = joinpath(output_dir, "$(test_name).csv")
    cp(source_file, dest_file, force=true)
    println("Copied $test_name.csv from demo/device/ to demo/output/")
end

"""
    demo_batch_copy(output_dir=nothing, delay=2.0)

Automatically copies test files from demo/device/ to demo/output/ one by one to demonstrate live plotting.
"""
function demo_batch_copy(output_dir=nothing, delay=2.0)
    # Set default output directory relative to project root
    if output_dir === nothing
        current_dir = pwd()
        project_root = endswith(current_dir, "demo") ? dirname(current_dir) : current_dir
        output_dir = joinpath(project_root, "demo", "output")
    end

    # Get all CSV files from device folder
    project_root = endswith(pwd(), "demo") ? dirname(pwd()) : pwd()
    device_dir = joinpath(project_root, "demo", "device")

    if !isdir(device_dir)
        println("Device directory not found: $device_dir")
        return
    end

    csv_files = filter(f -> endswith(f, ".csv"), readdir(device_dir))
    test_files = [replace(f, ".csv" => "") for f in csv_files]

    println("Starting automatic file copying demo...")
    println("Files will be copied every $delay seconds")

    for (i, test_name) in enumerate(test_files)
        sleep(delay)
        copy_test_file(test_name, output_dir)
        println("Copied file $i/$(length(test_files)): $test_name")
    end

    println("Demo batch copy completed!")
end

# Quick start functions
"""Run the demo with live plotting"""
function run_demo()
    demo_live_plot()
end

"""Run demo with automatic file copying"""
function run_auto_demo()
    demo_batch_copy()
end

"""List available test files in demo/device/"""
function list_demo_files()
    current_dir = pwd()
    project_root = endswith(current_dir, "demo") ? dirname(current_dir) : current_dir
    test_dir = joinpath(project_root, "demo", "device")

    if isdir(test_dir)
        csv_files = filter(f -> endswith(f, ".csv"), readdir(test_dir))
        println("Available demo files:")
        for (i, file) in enumerate(csv_files)
            name_without_ext = replace(file, ".csv" => "")
            println("  $i. $name_without_ext")
        end
        println("\nUsage: copy_test_file(\"filename\")")
    else
        println("Demo device directory not found: $test_dir")
    end
end

# ─────────────────────────────────────────────────────────────────
# CCD broadband TA demo
# ─────────────────────────────────────────────────────────────────

function _demo_root()
    current_dir = pwd()
    project_root = endswith(current_dir, "demo") ? dirname(current_dir) : current_dir
    return joinpath(project_root, "demo")
end

"""
    _generate_ccd_test_data(device_dir)

Generate synthetic broadband transient absorption data as CCDABS + T_scale
file pairs plus a shared wavelength axis file. Creates a set of scans with
different decay lifetimes to simulate sequential acquisitions.

Spectral features (in wavelength space, 400–700 nm):
- Ground state bleach (negative ΔA, ~500 nm)
- Excited state absorption (positive ΔA, ~560 nm)
- Stimulated emission (negative ΔA, ~630 nm)
"""
function _generate_ccd_test_data(device_dir)
    has_data = isdir(device_dir) && !isempty(filter(f -> startswith(f, "CCDABS"), readdir(device_dir)))
    has_wl = isdir(device_dir) && isfile(joinpath(device_dir, "wavelength.txt"))
    if has_data && has_wl
        return
    end
    # Regenerate all files if wavelength.txt is missing (old format)
    mkpath(device_dir)

    n_wl = 128
    n_time = 50
    wavelengths = collect(range(400.0, 700.0, length=n_wl))
    t_delays = collect(range(-2.0, 20.0, length=n_time))

    # Spectral features in wavelength space (nm)
    gsb = (center=500.0, width=20.0)
    esa = (center=560.0, width=30.0)
    se  = (center=630.0, width=25.0)

    scans = [
        ("scan1", 3.0, 0.05),   # (name, lifetime_ps, amplitude)
        ("scan2", 5.0, 0.08),
        ("scan3", 1.5, 0.03),
        ("scan4", 8.0, 0.10),
    ]

    rng = MersenneTwister(42)

    for (name, tau, amp) in scans
        da = zeros(n_time, n_wl)
        for i in eachindex(t_delays)
            t = t_delays[i]
            t <= 0 && continue
            decay = exp(-t / tau)
            for j in eachindex(wavelengths)
                wl = wavelengths[j]
                g = -amp * exp(-(wl - gsb.center)^2 / (2 * gsb.width^2))
                e =  amp * 0.6 * exp(-(wl - esa.center)^2 / (2 * esa.width^2))
                s = -amp * 0.4 * exp(-(wl - se.center)^2 / (2 * se.width^2))
                da[i, j] = (g + e + s) * decay + randn(rng) * amp * 0.01
            end
        end

        # CCDABS: header line + tab-delimited matrix
        open(joinpath(device_dir, "CCDABS_$name.lvm"), "w") do io
            println(io, join(["col$j" for j in 1:n_wl], "\t"))
            for i in eachindex(t_delays)
                println(io, join(da[i, :], "\t"))
            end
        end

        # T_scale: header line + single column of time delays
        open(joinpath(device_dir, "T_scale_$name.lvm"), "w") do io
            println(io, "time_ps")
            for t in t_delays
                println(io, t)
            end
        end
    end

    # Wavelength axis file (shared across all scans)
    open(joinpath(device_dir, "wavelength.txt"), "w") do io
        println(io, "wavelength_nm")
        for wl in wavelengths
            println(io, wl)
        end
    end

    println("Generated $(length(scans)) CCD test data pairs in $device_dir")
end

"""
    demo_live_ccd(output_dir=nothing)

Demonstrates the live CCD heatmap functionality using synthetic broadband
transient absorption data. Generates test data on first run.

# Usage
1. Run this function to start monitoring demo/output_ccd/
2. Copy file pairs with `copy_ccd_pair("scan1")` or run `run_auto_ccd_demo()`
3. Watch the heatmap update in real time
"""
function demo_live_ccd(output_dir=nothing)
    demo_dir = _demo_root()
    device_dir = joinpath(demo_dir, "device_ccd")

    if output_dir === nothing
        output_dir = joinpath(demo_dir, "output_ccd")
    end
    mkpath(output_dir)

    # Generate test data if needed
    _generate_ccd_test_data(device_dir)

    println("=== QPSView Live CCD Demo ===")
    println("1. Copy CCD file pairs into: $output_dir")
    println("2. Watch the heatmap update automatically!")
    println("3. Available test scans:")

    if isdir(device_dir)
        scans = [replace(f, "CCDABS_" => "", ".lvm" => "")
                 for f in readdir(device_dir) if startswith(f, "CCDABS")]
        for (i, name) in enumerate(scans)
            println("   $i. $name")
        end
    end

    println("\n4. Starting live CCD monitor...")
    println("5. REPL remains available for copying files\n")

    task = live_ccd(output_dir; file_ext=".lvm", waittime=0.5)

    println("  Try: copy_ccd_pair(\"scan1\") or run_auto_ccd_demo()")
    return task
end

"""
    copy_ccd_pair(scan_name, output_dir=nothing; include_tscale=true)

Copy a CCDABS file from demo/device_ccd/ to demo/output_ccd/.
By default also copies the matching T_scale file for the time axis.

Set `include_tscale=false` to copy only the matrix data — the live panel
will fall back to pixel indices on the time axis.
"""
function copy_ccd_pair(scan_name::String, output_dir=nothing; include_tscale::Bool=true)
    demo_dir = _demo_root()
    device_dir = joinpath(demo_dir, "device_ccd")

    if output_dir === nothing
        output_dir = joinpath(demo_dir, "output_ccd")
    end
    mkpath(output_dir)

    ccdabs = "CCDABS_$scan_name.lvm"
    src_ccd = joinpath(device_dir, ccdabs)

    if !isfile(src_ccd)
        println("Scan not found: $scan_name")
        println("Available scans:")
        if isdir(device_dir)
            scans = [replace(f, "CCDABS_" => "", ".lvm" => "")
                     for f in readdir(device_dir) if startswith(f, "CCDABS")]
            for name in scans
                println("  - $name")
            end
        end
        return
    end

    # Copy wavelength file on first pair (static, doesn't change between scans)
    wl_src = joinpath(device_dir, "wavelength.txt")
    wl_dst = joinpath(output_dir, "wavelength.txt")
    if isfile(wl_src) && !isfile(wl_dst)
        cp(wl_src, wl_dst)
    end

    if include_tscale
        tscale = "T_scale_$scan_name.lvm"
        src_tsc = joinpath(device_dir, tscale)
        if isfile(src_tsc)
            cp(src_tsc, joinpath(output_dir, tscale), force=true)
        end
    end

    cp(src_ccd, joinpath(output_dir, ccdabs), force=true)
    label = include_tscale ? "pair" : "matrix only"
    println("Copied $scan_name ($label) to output_ccd/")
end

"""
    demo_batch_ccd_copy(output_dir=nothing, delay=3.0)

Automatically copy all CCD test pairs from demo/device_ccd/ to demo/output_ccd/
one by one with a delay between each.
"""
function demo_batch_ccd_copy(output_dir=nothing, delay=3.0)
    demo_dir = _demo_root()
    device_dir = joinpath(demo_dir, "device_ccd")

    if !isdir(device_dir)
        println("Device directory not found. Run demo_live_ccd() first to generate test data.")
        return
    end

    scans = [replace(f, "CCDABS_" => "", ".lvm" => "")
             for f in sort(readdir(device_dir)) if startswith(f, "CCDABS")]

    println("Starting automatic CCD file copying...")
    println("Pairs will be copied every $delay seconds")

    for (i, name) in enumerate(scans)
        sleep(delay)
        copy_ccd_pair(name, output_dir)
        println("Copied pair $i/$(length(scans)): $name")
    end

    println("CCD batch copy completed!")
end

"""Run the CCD demo with live heatmap"""
run_ccd_demo() = demo_live_ccd()

"""Run CCD demo with automatic file copying"""
run_auto_ccd_demo() = demo_batch_ccd_copy()

"""List available CCD test scans"""
function list_ccd_scans()
    device_dir = joinpath(_demo_root(), "device_ccd")
    if isdir(device_dir)
        scans = [replace(f, "CCDABS_" => "", ".lvm" => "")
                 for f in readdir(device_dir) if startswith(f, "CCDABS")]
        println("Available CCD test scans:")
        for (i, name) in enumerate(scans)
            println("  $i. $name")
        end
        println("\nUsage: copy_ccd_pair(\"scan_name\")")
    else
        println("No CCD test data found. Run run_ccd_demo() to generate it.")
    end
end