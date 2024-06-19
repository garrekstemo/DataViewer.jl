"""
    livepanel(datadir::String, load_function::Function, file_ext::String; waittime = 0.1, theme = nothing)

A panel with a plot that updates when a new data file is found
in the given directory. Satellite panels can be opened via buttons.
"""
function live_image(
        datadir::String,
        file_ext::String=".lvm";
        wavelengths_file = nothing,
        waittime = 0.1,
    )
    datadir = abspath(datadir)

    GLMakie.activate!()
    fig = Figure(size = (600, 900))

    img = Observable(rand(200, 100))
    time = Observable(collect(range(0, 100, length = size(to_value(img), 1))))
    if wavelengths_file !== nothing
        λs = Observable(load_wavelengths(wavelengths_file))
        img[] = rand(length(to_value(time)), length(to_value(λs)))
    else
        num_wavelengths = size(to_value(img), 2)
        λs = Observable(collect(range(0, num_wavelengths, length = num_wavelengths)))
    end
    Δy = @lift(abs($λs[2] - $λs[1]))
    y_line = Observable(to_value(λs)[1])
    y_idx = Observable(1)
    cut = @lift($img[:, $y_idx])


    sc = display(fig)
    DataInspector(fig)

    figbutton = Button(fig, label = "New Figure")
    fig[2, 1] = vgrid!(
        figbutton;
        tellwidth = false,
        )
    
    ax1 = Axis(fig[1, 1][1, 1], 
            title = "Line profiler",
            xlabel = "Time (ps)", 
            ylabel = "Wavelength (nm)",
            xticks = LinearTicks(7),
            yticks = LinearTicks(7),
            )

    hm = heatmap!(time, λs, img)
    hlines!(y_line, color = :red)

    ax2 = Axis(fig[1, 1][2, 1],
        xlabel = "Time (ps)",
        ylabel = "Intensity (Arb.)",
        yticklabelspace = 50.0,
        xticks = LinearTicks(7),
        yticks = LinearTicks(7),
        )
    line = lines!(time, cut, color = :firebrick3)
    livetext = text!(" • Live", color = :red, space = :relative, align = (:left, :bottom))

    # Events

    on(events(fig).mouseposition) do mpos
        if is_mouseinside(ax1)
            y_line[] =  trunc(Int, mouseposition(ax1.scene)[2])
            y_idx[] = findfirst(isapprox(y_line[], atol = Δy[]), λs[])
            autolimits!(ax2)
        end
    end

    on(figbutton.clicks) do _
        newfig = satellite_image(to_value(img), to_value(time), to_value(λs), ax1.title)
        display(GLMakie.Screen(), newfig)
        DataInspector(newfig)
    end

    # Watch for new data
    found_files = Dict("CCDABS" => false, "T_scale" => false)
    files = Dict("CCDABS" => "", "T_scale" => "")

    while true
        file, event = watch_folder(datadir)
        sleep(waittime)

        if isa(file, String) && file != "." && file != ".." && endswith(file, file_ext)
            if findfirst('\\', file) == 1
                file = file[2:end]
            end
            
            println("New file: ", file)
        
            if file[1:6] == "CCDABS"
                found_files["CCDABS"] = true
                files["CCDABS"] = joinpath(datadir, file)
            elseif file[1:7] == "T_scale"
                found_files["T_scale"] = true
                files["T_scale"] = joinpath(datadir, file)
            end

            if found_files["CCDABS"] && found_files["T_scale"]
                new_img, filename = load_image(files["CCDABS"])
                new_time = vec(readdlm(files["T_scale"], skipstart=1)) ./ 1e3
                if new_img !== nothing && length(new_time) == size(new_img, 1)
                    img.val = new_img
                    time.val = new_time
                    num_ypoints = size(to_value(img), 2)

                    if wavelengths_file !== nothing
                        λs.val = load_wavelengths(wavelengths_file)
                    else
                        λs.val = collect(range(0, num_ypoints, length = num_ypoints))
                    end
                    notify(img)
                    ax1.title = filename
                end
                found_files = Dict("CCDABS" => false, "T_scale" => false)
            end
            autolimits!(ax1)
            autolimits!(ax2)
        end
    end
end



"""
    satellite_image(, title)

A satellite panel that appears upon clicking a button on the live panel.
Not a user-facing function.
"""
function satellite_image(img, time, λs, title)

    fig = Figure(size = (600, 900))
    DataInspector(fig)

    Δy = abs(λs[2] - λs[1])
    y_line = Observable(λs[1])
    y_idx = Observable(1)
    cut = @lift(img[:, $y_idx])
    save_button = Button(fig, label = "Save as png")
    
    fig[2, 1] = vgrid!(
        save_button;
        tellwidth = false,
        )

    ax1 = Axis(fig[1, 1][1, 1], 
            title = title,
            xlabel = "Time (ps)",
            ylabel = "Wavelength (nm)",
            xticks = LinearTicks(7),
            yticks = LinearTicks(7),
            )

    hm = heatmap!(time, λs, img)
    hlines!(y_line, color = :red)

    ax2 = Axis(fig[1, 1][2, 1],
        xlabel = "Time (ps)",
        ylabel = "Intensity (Arb.)",
        yticklabelspace = 50.0,
        xticks = LinearTicks(7),
        yticks = LinearTicks(7),
        )
    line = lines!(time, cut)

    on(events(fig).mouseposition) do mpos
        if is_mouseinside(ax1)
            y_line[] =  trunc(Int, mouseposition(ax1.scene)[2])
            y_idx[] = findfirst(isapprox(y_line[], atol = Δy), λs)
            autolimits!(ax2)
        end
    end

    on(save_button.clicks) do _
        save_folder = "./plots/"
        if !isdir(save_folder)
            mkdir(save_folder)
        end

        plotname = to_value(title)
        save_path = abspath(joinpath(save_folder, plotname * ".pdf"))
        to_save = make_savefig(x, y, plotname, to_value(ax.xlabel), to_value(ax.ylabel))
        save(save_path, to_save, backend = CairoMakie)
        println("Saved figure to ", save_path)  
    end
    
    return fig
end