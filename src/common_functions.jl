function make_savefig(x, y, title, xlabel, ylabel)
    fig = Figure()
    ax = Axis(fig[1, 1], title = title, 
            xlabel = xlabel,
            ylabel = ylabel,
            xticks = LinearTicks(10))
    lines!(ax, x, y)
    return fig
end