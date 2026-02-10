module QPSView

using CSV
using Dates
using DelimitedFiles
using FileWatching
using GLMakie
using CairoMakie
import QPSTools as QPS

include("common_functions.jl")  # AXIS_LABELS used by other modules
include("themes.jl")
include("loading_functions.jl")
include("scan_satellite.jl")
include("live_scan.jl")
include("live_plot.jl")
include("live_image.jl")
include("live_ccd.jl")

export live_plot, live_image, live_ccd, live_scan, scan_satellite, cleanup!
export load_mir, load_test_data

# Themes
export dataviewer_theme, dataviewer_colors
export apply_theme!, apply_theme_to_axis!
# Legacy aliases (deprecated)
export dataviewer_light_theme, dataviewer_light_colors

using PrecompileTools

@setup_workload begin
    _pcdir = mktempdir()

    _csv_file = joinpath(_pcdir, "pc.csv")
    open(_csv_file, "w") do io
        println(io, "x,y")
        for i in 1:20
            println(io, "$i,$(sin(Float64(i)))")
        end
    end

    _img_file = joinpath(_pcdir, "pc.dat")
    open(_img_file, "w") do io
        println(io, "c1\tc2\tc3\tc4\tc5")
        for i in 1:5
            println(io, join(Float64.(i:i+4), "\t"))
        end
    end

    _wn = collect(range(1900.0, 2100.0, length=201))
    _y_spec = @. 0.8 * exp(-(_wn - 1990.0)^2 / 50.0) +
                 1.2 * exp(-(_wn - 2020.0)^2 / 128.0) -
                 0.6 * exp(-(_wn - 2050.0)^2 / 72.0)

    _lvm_dir = joinpath(pkgdir(QPSView), "testdata", "MIRpumpprobe")
    _lvm_file = joinpath(_lvm_dir, "bare_1M_10ps.lvm")
    _has_lvm = isfile(_lvm_file)

    @compile_workload begin
        # Data loading
        load_test_data(_csv_file)
        load_image(_img_file)

        if _has_lvm
            load_mir(_lvm_file)
        end

        # Theme and colors
        dataviewer_colors(true)
        dataviewer_colors(false)
        dataviewer_theme(true)
        dataviewer_theme(false)

        # Utilities
        get_filename("/path/to/file.csv")
        _normdir("/tmp/testdir")
        _is_spectral_data((x=[1.0, 2.0], y=[3.0, 4.0]), AXIS_LABELS.wavelength)
        _is_spectral_data((x=[1.0, 2.0], y=[3.0, 4.0]), AXIS_LABELS.time_ps)

        # Peak detection
        _peaks = QPS.find_peaks(_wn, _y_spec; min_prominence=0.15)
        QPS.peak_table(_peaks)
        QPS.find_peaks(_wn, -_y_spec; min_prominence=0.15)

        # Exponential fitting (do_fit! path)
        _t_kin = collect(range(-1.0, 10.0, length=100))
        _y_kin = @. 0.5 * exp(-_t_kin / 3.0) * (_t_kin > 0.0)
        _trace = QPS.TATrace(_t_kin, _y_kin)
        QPS.find_peak_time(_t_kin, _y_kin)
        _fit = QPS.fit_exp_decay(_trace; irf=false, t_start=1.0)
        QPS.predict(_fit, _t_kin[_t_kin .>= 1.0])

        # Makie GUI construction (no display calls)
        try
            _colors = dataviewer_colors(true)

            _fig = Figure(size=(650, 500))
            DataInspector(_fig)
            _ax = Axis(_fig[1, 1],
                xlabel="x", ylabel="y", title="test",
                xticks=LinearTicks(7), yticks=LinearTicks(5))
            apply_theme_to_axis!(_ax, _colors)
            _fig.scene.backgroundcolor[] = Makie.to_color(_colors[:background])

            _xo = Observable(collect(1.0:20.0))
            _yo = Observable(sin.(collect(1.0:20.0)))
            _yfit = Observable(fill(NaN, 20))

            _l1 = lines!(_ax, _xo, _yo, color=_colors[:data], linewidth=1.5,
                label="data")
            _l2 = lines!(_ax, _xo, _yfit, color=_colors[:fit], linewidth=1.5,
                visible=false)
            _s1 = scatter!(_ax, _xo, _yo, color=_colors[:warning],
                marker=:dtriangle, markersize=12, visible=false)
            _ft = text!(_ax, 0.98, 0.5, text="test", space=:relative,
                align=(:right, :center), fontsize=14, visible=false)
            text!(_ax, 0.02, 0.98, text="", space=:relative,
                align=(:left, :top), fontsize=12, visible=false)

            # Derived observables (@lift path used in satellite_panel)
            _neg = @lift(-$_yo)

            # to_value (used throughout satellite_panel callbacks)
            to_value(_xo)
            to_value(_yo)

            # Makie.update! (used in satellite_panel toggle/fit callbacks)
            Makie.update!(_l2; visible=true)
            Makie.update!(_l2; visible=false)
            Makie.update!(_ft; visible=true)
            Makie.update!(_ft; visible=false)
            Makie.update!(_s1; visible=true)
            Makie.update!(_s1; visible=false)

            # Rich text (peak annotations in satellite_panel)
            rich("ESA: 2000.0", color=_colors[:warning])
            rich("GSB: 1990.0", color=_colors[:fit])

            # Menu with styled colors (satellite_panel file history)
            _menu = Menu(_fig, options=["a", "b", "c"], default="a", width=200)
            _style_menu!(_menu, _colors)

            _btn = Button(_fig, label="Test")
            _btn2 = Button(_fig, label="Test2")
            _lbl = Label(_fig, "t₀ (ps):", fontsize=14, color=_colors[:foreground])
            _tbox = Textbox(_fig, stored_string="1.0", width=80,
                textcolor=_colors[:foreground],
                boxcolor=_colors[:background],
                bordercolor=_colors[:foreground])

            # vgrid! (satellite_panel button column)
            _fig[1, 1] = vgrid!(_menu, _btn, _btn2, _lbl, _tbox;
                tellheight=false, width=220)
            # hgrid! (live_plot button row)
            _fig[2, 1] = hgrid!(_btn; tellwidth=false)

            # axislegend (satellite_panel pump on/off legend)
            _leg = axislegend(_ax, position=:rb,
                backgroundcolor=(Makie.to_color(_colors[:background]), 0.8),
                labelcolor=Makie.to_color(_colors[:foreground]),
                framecolor=Makie.to_color(_colors[:foreground]))

            autolimits!(_ax)

            # apply_theme! with legend (satellite_panel theme toggle)
            apply_theme!(_fig, _ax, [(_l1, :data)], [_btn];
                dark=false, legend=_leg, texts=[(_ft, :foreground)])

            # make_savefig (save button in satellite_panel)
            make_savefig(collect(1.0:20.0), sin.(collect(1.0:20.0)),
                "test", "x", "y")

            # Heatmap for live_image
            _fig2 = Figure(size=(600, 900))
            _ax2 = Axis(_fig2[1, 1])
            _hm_data = Observable(rand(10, 10))
            heatmap!(_ax2, _hm_data)
            hlines!(_ax2, 5.0, color=:red)

            # CCD heatmap (live_ccd / satellite_ccd) — plain values + Makie.update!
            _ccd_fig = Figure(size=(800, 900))
            _ccd_ax = Axis(_ccd_fig[1, 1])
            _ccd_wl = collect(range(400.0, 700.0, length=10))
            _ccd_time = collect(range(-2.0, 20.0, length=10))
            _ccd_img = randn(10, 10) .* 0.01
            _ccd_hm = heatmap!(_ccd_ax, _ccd_wl, _ccd_time, _ccd_img,
                colormap=:RdBu, colorrange=(-0.01, 0.01))
            Colorbar(_ccd_fig[1, 2], _ccd_hm, label=AXIS_LABELS.delta_a)
            _ccd_vl = vlines!(_ccd_ax, _ccd_wl[1], color=:red)
            _ccd_cut = [Point2f(_ccd_time[i], _ccd_img[1, i]) for i in eachindex(_ccd_time)]
            _ccd_ax2 = Axis(_ccd_fig[2, 1])
            _ccd_cl = lines!(_ccd_ax2, _ccd_cut)
            # Precompile Makie.update! paths
            Makie.update!(_ccd_hm, _ccd_wl, _ccd_time, _ccd_img; colorrange=(-0.01, 0.01))
            Makie.update!(_ccd_vl; arg1=_ccd_wl[5])
            Makie.update!(_ccd_cl; arg1=_ccd_cut)
            make_savefig_heatmap(randn(10, 10) .* 0.01, "precompile")
            make_savefig_heatmap(randn(10, 10) .* 0.01, "precompile";
                x=collect(1.0:10.0), y=collect(1.0:10.0))
            _find_wavelength_file(mktempdir())

            # live_scan GUI construction
            _ls_delays = collect(range(-1.0, 10.0, length=50))
            _ls_signal = Observable(zeros(50))
            _ls_index = Observable(0)
            _ls_status = Observable(:idle)
            _ls_abort = Ref(false)
            _ls_desc = Observable("")
            _ls_prog = Observable(0.0)
            _ls_fig = live_scan(;
                delays=_ls_delays, signal=_ls_signal, index=_ls_index,
                status=_ls_status, abort=_ls_abort,
                description=_ls_desc, progress=_ls_prog)

            # scan_satellite GUI construction
            _ss_trace = QPS.TATrace(_t_kin, _y_kin)
            _ss_fig = scan_satellite(_ss_trace; title="precompile", dark_theme=true)
        catch
            # Graceful fallback if display initialization fails
        end
    end
end

end # module
