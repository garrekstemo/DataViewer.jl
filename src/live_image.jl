"""
    livepanel(datadir::String, load_function::Function, file_ext::String; waittime = 0.1, theme = nothing)

A panel with a plot that updates when a new data file is found
in the given directory. Satellite panels can be opened via buttons.
"""
function live_image(datadir::String,
        load_function::Function=load_image,
        file_ext::String=".lvm";
        wavelength = nothing,
        waittime = 0.1,
        theme = nothing
    )
    datadir = abspath(datadir)
    if theme !== nothing
        set_theme!(theme)
    end

    fig = Figure(size = (600, 900))

    img = Observable(rand(100, 100))
    time = Observable(range(0, 100, length = size(to_value(img), 1)))
    if wavelength !== nothing
        λs = Observable(vec(readdlm(wavelength)))
        img = Observable(rand(length(to_value(time)), length(to_value(λs))))
    else
        λs = Observable(range(400, 800, length = size(to_value(img), 2)))
    end
    λ_step = @lift($(λs)[2] - $(λs)[1])
    λ_order = @lift(10.0^floor(Int, log10($λ_step)))
    y_line = Observable(700.0)
    cut = Observable(to_value(img)[:, 1])


    sc = display(fig)
    DataInspector(fig)

    figbutton = Button(fig, label = "New Figure")
    fig[2, 1] = vgrid!(
        figbutton;
        tellwidth = false,
        )
    
    ax1 = Axis(fig[1, 1][1, 1], xlabel = "Time (ps)", ylabel = "Wavelength (nm)")

    hm = heatmap!(time, λs, img)
    hlines!(y_line, color = :red)

    ax2 = Axis(fig[1, 1][2, 1],
        xlabel = "Time (ps)",
        ylabel = "Intensity (Arb.)",
        yticklabelspace = 50.0
        )
    line = lines!(ax2, cut, color = :firebrick3)
    livetext = text!(" • Live", color = :red, space = :relative, align = (:left, :bottom))

    # Events

    on(events(ax1).mouseposition) do mpos
        y_line[] =  trunc(Int, mouseposition(ax1.scene)[2])
        yaxis_limits = ax1.yaxis.attributes.limits[]

        if y_line[] >= yaxis_limits[1] && y_line[] <= yaxis_limits[2]
            y_idx = findfirst(isapprox(y_line[], atol = λ_order[]), λs[])
            cut[] = to_value(img)[:, y_idx]
        end
        autolimits!(ax2)
    end

    on(figbutton.clicks) do _
        newfig = satellite_image(to_value(img), to_value(time), to_value(λs))
        display(GLMakie.Screen(), newfig)
    end

    # Watch for new data
    while true
        (file, event) = watch_folder(datadir)
        sleep(waittime)
        
        if endswith(file, file_ext)

            if findfirst('\\', file) == 1
                file = file[2:end]
            end
            println("New file: ", file)            

            img[], filename = load_function(joinpath(datadir, file))
            ax1.title = filename
            autolimits!(ax1)
        end
    end

end


"""
    satellite_image(, title)

A satellite panel that appears upon clicking a button on the live panel.
Not a user-facing function.
"""
function satellite_image(img, time, λs)

    fig = Figure()
    DataInspector()

    # Observables and widgets

    y_line = Observable(10.0)
    cut = Observable(img[:, 1])
    save_button = Button(fig, label = "Save as png")
    
    # fig[2, 1] = vgrid!(
    #     save_button;
    #     tellwidth = false,
    #     )
    
    ax1 = Axis(fig[1, 1][1, 1], xlabel = "Time (ps)", ylabel = "Wavelength (nm)")

    hm = heatmap!(ax1, img)
    hlines!(y_line, color = :red)

    ax2 = Axis(fig[1, 1][2, 1],
        xlabel = "Time (ps)",
        ylabel = "Intensity (Arb.)",
        yticklabelspace = 50.0
        )
    line = lines!(ax2, cut, color = :firebrick3)



    on(events(ax1).mouseposition) do mpos
        autolimits!(ax2)
    end
end