using DataViewer
using CSV

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
        # Find the project root (where DataViewer.jl package is)
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

    println("=== DataViewer Live Plot Demo ===")
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