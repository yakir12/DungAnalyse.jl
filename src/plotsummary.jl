using Distributions, StatsBase

function plothomingsearching(todo, level)
    @pgf p = GroupPlot(
                       {
                        group_style =
                        {
                         group_size = "2 by 1", yticklabels_at="edge left"
                        },
                        legend_style={legend_columns=-1},
                        legend_to_name={"CommonLegend"},
                        xmajorgrids,
                        ymajorgrids,
                        # "ytick distance=25",
                        # "xtick distance=25",
                        # scale_only_axis, 
                        xlabel = "X (cm)",
                        axis_equal_image,
                        ymin = -180,
                        ymax = 130,
                        xmin = -180,
                        xmax = 180,
                       },
                      );
    for x in values(todo)
        for r in x.runs
            rotate!(r.data)
            center2!(r.data, r.data.originalnest)
        end
    end
    @pgf push!(p, {ylabel = "Y (cm)", xmin = -80, xmax = 80}, Plot({only_marks, color = "black"}, Coordinates([0], [0])));
    push!(p, LegendEntry("nest"))
    for (x, color) in zip(values(todo), ("magenta", "green", "blue", "cyan"))
        r = x.runs[1]
        @pgf push!(p, Plot({no_markers, color = color*"!50"}, Coordinates(Tuple.(r.data.homing))))
        push!(p, LegendEntry(get(x.runs[1].metadata.setup, level, "")))
    end
    for (x, color) in zip(values(todo), ("magenta", "green", "blue", "cyan"))
        for r in x.runs[2:end]
            @pgf push!(p, Plot({no_markers, color = color*"!50"}, Coordinates(Tuple.(r.data.homing))))
        end
    end
    labels = Dict{Tuple{Float64, Float64}, Int}()
    for (x, color) in zip(values(todo), ("magenta", "green", "blue", "cyan"))
        sina, cosa = mean(x.runs) do r
            xdata = first.(r.data.homing)
            xdata .-= mean(xdata)
            ydata = last.(r.data.homing)
            n = length(xdata)
            a, _ = hcat(xdata, ones(n))\ydata
            α = atan(a)
            if α < 0 
                α += π
            end
            sina, cosa = sincos(α)
            SVector(sina, cosa)
        end
        α = atan(sina, cosa)
        ad = 90 - round(Int, rad2deg(α))
        a = tan(α)
        μ = mean(xy for r in x.runs for xy in r.data.homing)
        b = μ[2] - a*μ[1]
        m,M = extrema(yy for r in x.runs for (_, yy) in r.data.homing)
        # m -= 10
        # M += 10
        m = (m - b)/a
        M = (M - b)/a
        xl = [m, M]
        yl = a*xl .+ b
        labels[(xl[2], yl[2])] = ad
        @pgf push!(p, Plot({no_markers, color = color*"!75!black", ultra_thick, "->", ">=stealth"}, Coordinates(xl, yl)), )
    end
    for (k,v) in labels
        x,y = k
        anchor = v < 0 ? "south west" : "south east"
        push!(p, "\\node[inner sep = 0, fill=white, fill opacity = 0.5, text opacity=1, anchor = $anchor] at ($x,$y) {\$$v^{\\circ}\$};")
    end
    for x in values(todo)
        for r in x.runs
            rotate!(r.data)
            center2!(r.data, r.data.originalnest)
        end
    end
    @pgf push!(p, {}, Plot({only_marks, color = "black"}, Coordinates([0], [0])));
    push!(p, LegendEntry("nest"))
    for (x, color) in zip(values(todo), ("magenta", "green", "blue", "cyan"))
        r = x.runs[1]
        @pgf push!(p, Plot({no_markers, color = color*"!50"}, Coordinates(Tuple.(r.data.searching))))
        push!(p, LegendEntry(get(x.runs[1].metadata.setup, level, "")))
    end
    for (x, color) in zip(values(todo), ("magenta", "green", "blue", "cyan"))
        for r in x.runs[2:end]
            @pgf push!(p, Plot({no_markers, color = color*"!50"}, Coordinates(Tuple.(r.data.searching))))
        end
    end
    for (x, color) in zip(values(todo), ("magenta", "green", "blue", "cyan"))
        xy = reduce(vcat, r.data.searching for r in x.runs)
        xy2 = reduce(hcat, xy)
        d = fit_mle(MvNormal, xy2)
        μx, μy = mean(d)
        σ = var(d)
        fwhm = 2sqrt(2log(2)).*sqrt.(σ)
        rx, ry = fwhm/2
        t = range(0, 2π, length = 100)
        @pgf push!(p, Plot({fill = color, draw = "none", fill_opacity = 0.25}, Coordinates(μx .+ rx.*cos.(t), μy .+ ry.*sin.(t))), Plot({only_marks, color = color, draw = color*"!80!black"}, Coordinates([μx], [μy])))
    end
    p = TikzPicture(p);
    push!(p, "\\path (group c1r1.north west) -- node[above]{\\ref{CommonLegend}} (group c2r1.north east);");
    p = push_preamble!(TikzDocument(p), raw"""
                       \def\mystrut{\vphantom{hg}}
                       %\def\mystrut{\strut}
                       \pgfplotsset{
                                    legend style={font=\mystrut},
                                    y tick label style={font=\mystrut}
                                   }
                       """
                      )
    pgfsave(string("homing-searching.pdf"), p)
    # pgfsave(string(join(keys(todo), " "), "homing-searching.pdf"), p)
end

