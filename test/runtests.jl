using Test
using CSV
using DelimitedFiles
import QPS

# Include source files directly to test without GLMakie dependency.
# This allows headless testing without starting a display.
# common_functions.jl must come first (defines AXIS_LABELS, cleanup!, etc.)
include(joinpath(@__DIR__, "..", "src", "common_functions.jl"))
include(joinpath(@__DIR__, "..", "src", "loading_functions.jl"))

const TESTDATA_DIR = joinpath(@__DIR__, "..", "testdata")
const DEMO_DIR = joinpath(@__DIR__, "..", "demo", "device")

@testset "DataViewer Tests" begin

    @testset "load_test_data (CSV)" begin
        @testset "loads valid CSV file" begin
            filepath = joinpath(DEMO_DIR, "sine.csv")
            x, y, xlabel, ylabel, filename, data = load_test_data(filepath)

            @test length(x) == length(y)
            @test length(x) > 0
            @test xlabel == "x"
            @test ylabel == "y"
            @test filename == "sine"
            @test data isa NamedTuple
            @test haskey(data, :x) && haskey(data, :y)
        end

        @testset "loads all demo CSV files" begin
            csv_files = filter(f -> endswith(f, ".csv"), readdir(DEMO_DIR))
            @test length(csv_files) > 0

            for file in csv_files
                filepath = joinpath(DEMO_DIR, file)
                result = load_test_data(filepath)
                x, y, xlabel, ylabel, filename, data = result

                @test length(x) == length(y)
                @test length(x) > 0
                @test filename == chop(file, tail=4)
            end
        end

        @testset "synthetic CSV data" begin
            # Create temp CSV with known values
            tmpdir = mktempdir()
            tmpfile = joinpath(tmpdir, "synthetic.csv")

            test_x = [1.0, 2.0, 3.0, 4.0, 5.0]
            test_y = [10.0, 20.0, 30.0, 40.0, 50.0]

            # Write CSV without DataFrames
            open(tmpfile, "w") do io
                println(io, "x,y")
                for (xi, yi) in zip(test_x, test_y)
                    println(io, "$xi,$yi")
                end
            end

            x, y, xlabel, ylabel, filename, data = load_test_data(tmpfile)

            @test x == test_x
            @test y == test_y
            @test filename == "synthetic"
            @test data isa NamedTuple
            @test length(data.x) == 5
        end
    end

    @testset "load_mir (LVM via QPS)" begin
        pump_probe_dir = joinpath(TESTDATA_DIR, "MIRpumpprobe")

        @testset "loads valid LVM files" begin
            lvm_files = filter(f -> endswith(f, ".lvm") && !startswith(f, "bad"), readdir(pump_probe_dir))

            for file in lvm_files
                filepath = joinpath(pump_probe_dir, file)
                result = load_mir(filepath)

                # load_mir returns (xdata, ydata, xlabel, ylabel, filename, PumpProbeData) or (nothing, ...)
                if result[1] !== nothing
                    xdata, ydata, xlabel, ylabel, filename, data = result
                    @test length(xdata) == length(ydata)
                    @test length(xdata) > 0
                    @test xlabel isa String
                    @test ylabel isa String
                    @test data isa QPS.PumpProbeData
                    @test length(data.time) > 0
                    @test size(data.on, 2) >= 1  # At least 1 channel
                end
            end
        end

        @testset "handles bad/empty files gracefully" begin
            bad_file = joinpath(pump_probe_dir, "bad_file.lvm")
            if isfile(bad_file)
                # Should not throw, should return nothing for data
                result = load_mir(bad_file)
                # Result should be a tuple (even if data is nothing)
                @test result isa Tuple
            end
        end
    end

    @testset "load_image" begin
        ccd_dir = joinpath(TESTDATA_DIR, "CCD")

        @testset "loads delimited image files" begin
            if isdir(ccd_dir)
                image_files = filter(f -> !startswith(f, "."), readdir(ccd_dir))

                for file in image_files
                    filepath = joinpath(ccd_dir, file)
                    if isfile(filepath)
                        result = load_image(filepath)
                        raw, filename = result

                        if raw !== nothing
                            @test raw isa Matrix
                            @test size(raw, 1) > 0
                            @test size(raw, 2) > 0
                        end
                    end
                end
            end
        end

        @testset "synthetic image data" begin
            tmpdir = mktempdir()
            tmpfile = joinpath(tmpdir, "test_image.dat")

            # Create synthetic 2D data with header row
            header = "col1\tcol2\tcol3\tcol4\tcol5"
            data = [
                1.0 2.0 3.0 4.0 5.0;
                6.0 7.0 8.0 9.0 10.0;
                11.0 12.0 13.0 14.0 15.0
            ]

            open(tmpfile, "w") do io
                println(io, header)
                writedlm(io, data)
            end

            raw, filename = load_image(tmpfile)

            @test raw !== nothing
            @test size(raw) == (3, 5)
            @test filename == "test_image"
        end
    end

    @testset "get_filename" begin
        @test get_filename("/path/to/file.csv") == "file"
        @test get_filename("/path/to/data.lvm") == "data"
        @test get_filename("simple.txt") == "simple"  # removes 4-char extension
        @test get_filename("/a/b/c/test_file.dat") == "test_file"
    end

    @testset "cleanup!" begin
        @testset "deletes files and clears watcher history" begin
            tmpdir = mktempdir()
            for i in 1:3
                write(joinpath(tmpdir, "sig_$i.lvm"), "data")
            end

            _watcher_registry[tmpdir] = Set(["sig_1.lvm", "sig_2.lvm"])

            cleanup!(tmpdir)

            @test isempty(readdir(tmpdir))
            @test isempty(_watcher_registry[tmpdir])
        end

        @testset "works with no watcher registered" begin
            tmpdir = mktempdir()
            write(joinpath(tmpdir, "stray.txt"), "data")

            cleanup!(tmpdir)

            @test isempty(readdir(tmpdir))
        end

        @testset "handles nonexistent directory" begin
            cleanup!("/nonexistent/dir/12345")  # should not throw
        end

        @testset "leaves subdirectories intact" begin
            tmpdir = mktempdir()
            write(joinpath(tmpdir, "file.lvm"), "data")
            mkdir(joinpath(tmpdir, "subdir"))
            write(joinpath(tmpdir, "subdir", "nested.txt"), "data")

            cleanup!(tmpdir)

            @test readdir(tmpdir) == ["subdir"]
            @test readdir(joinpath(tmpdir, "subdir")) == ["nested.txt"]
        end
    end

    @testset "_is_spectral_data" begin
        @testset "PumpProbeData with time axis" begin
            n = 10
            ppd_time = QPS.PumpProbeData(
                collect(1.0:n), zeros(n, 1), zeros(n, 1), zeros(n, 1),
                "2024-01-01", QPS.time_axis)
            @test _is_spectral_data(ppd_time, AXIS_LABELS.time_ps) == false
        end

        @testset "PumpProbeData with wavelength axis" begin
            n = 10
            ppd_wl = QPS.PumpProbeData(
                collect(400.0:10:490.0), zeros(n, 1), zeros(n, 1), zeros(n, 1),
                "2024-01-01", QPS.wavelength_axis)
            @test _is_spectral_data(ppd_wl, AXIS_LABELS.wavelength) == true
        end

        @testset "NamedTuple with xlabel fallback" begin
            nt = (x=[1.0, 2.0], y=[3.0, 4.0])
            @test _is_spectral_data(nt, AXIS_LABELS.wavelength) == true
            @test _is_spectral_data(nt, AXIS_LABELS.wavenumber) == true
            @test _is_spectral_data(nt, AXIS_LABELS.time_ps) == false
            @test _is_spectral_data(nt, "x") == false
        end
    end

    @testset "peak detection (synthetic spectrum)" begin
        # Synthetic wavenumber axis (1900-2100 cm⁻¹)
        wn = collect(range(1900.0, 2100.0, length=401))

        # Helper: Gaussian peak
        gauss(x, center, amp, sigma) = amp * exp.(-(x .- center).^2 ./ (2 * sigma^2))

        # Build spectrum:
        # 2 ESA peaks (positive) at 1990 and 2020 cm⁻¹
        # 1 GSB dip (negative) at 2050 cm⁻¹
        y_spectrum = gauss(wn, 1990.0, 0.8, 5.0) .+
                     gauss(wn, 2020.0, 1.2, 8.0) .-
                     gauss(wn, 2050.0, 0.6, 6.0)

        @testset "finds ESA peaks" begin
            esa_peaks = QPS.find_peaks(wn, y_spectrum; min_prominence=0.15)
            @test length(esa_peaks) == 2

            positions = sort([p.position for p in esa_peaks])
            @test abs(positions[1] - 1990.0) < 2.0
            @test abs(positions[2] - 2020.0) < 2.0
        end

        @testset "finds GSB dips" begin
            gsb_peaks = QPS.find_peaks(wn, -y_spectrum; min_prominence=0.15)
            @test length(gsb_peaks) >= 1

            # At least one GSB near 2050 cm⁻¹
            gsb_positions = [p.position for p in gsb_peaks]
            @test any(abs.(gsb_positions .- 2050.0) .< 2.0)

            # The peak near 2050 cm⁻¹ should be negative in original data
            gsb_idx = argmin(abs.(gsb_positions .- 2050.0))
            @test y_spectrum[gsb_peaks[gsb_idx].index] < 0
        end

        @testset "peak_table output" begin
            peaks = QPS.find_peaks(wn, y_spectrum; min_prominence=0.15)
            table = QPS.peak_table(peaks)
            @test occursin("Position", table)
            @test occursin("Intensity", table)
        end
    end

    @testset "peak detection (real spectral file)" begin
        spectrum_file = joinpath(TESTDATA_DIR, "MIRpumpprobe", "single_beam_spectrum.lvm")
        if isfile(spectrum_file)
            result = load_mir(spectrum_file)
            if result[1] !== nothing
                xdata, ydata, xlabel, ylabel, filename, data = result
                if _is_spectral_data(data, xlabel)
                    peaks = QPS.find_peaks(xdata, ydata; min_prominence=0.15)
                    @test peaks isa Vector{QPS.PeakInfo}
                end
            end
        end
    end

    @testset "edge cases" begin
        @testset "nonexistent file" begin
            @test_throws Exception load_test_data("/nonexistent/path/file.csv")
        end

        @testset "empty CSV" begin
            tmpdir = mktempdir()
            tmpfile = joinpath(tmpdir, "empty.csv")

            # CSV with header only
            open(tmpfile, "w") do io
                println(io, "x,y")
            end

            # Should handle gracefully (may throw or return empty)
            try
                result = load_test_data(tmpfile)
                x, y, _, _, _, data = result
                @test length(x) == 0
            catch e
                # It's acceptable to throw on truly empty data
                @test e isa Exception
            end
        end
    end

end
