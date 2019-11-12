using CoordinateTransformations, Rotations, Combinatorics


_getproperty(x::Track, ::Val{:homing}) = x.coords[1:x.tp]
_getproperty(x::Track, ::Val{:searching}) = x.coords[x.tp:end]
_getproperty(x::Track, ::Val{:searchcenter}) = mean(x.searching)
_getproperty(x::Track, ::Val{:turningpoint}) = x.coords[x.tp]
_getproperty(x::Track, ::Val{T}) where {T} = getfield(x, T)
Base.getproperty(x::Track, sym::Symbol) = _getproperty(x, Val(sym))

_getproperty(x::Common, ::Val{:homing}) = x.track.homing
_getproperty(x::Common, ::Val{:searching}) = x.track.searching
_getproperty(x::Common, ::Val{:searchcenter}) = x.track.searchcenter
_getproperty(x::Common, ::Val{:turningpoint}) = x.track.turningpoint
_getproperty(x::Common, ::Val{:pellet1}) = first(x.pellet.xy)
_getproperty(x::Common, ::Val{T}) where {T} = getfield(x, T)
Base.getproperty(x::Common, sym::Symbol) = _getproperty(x, Val(sym))

function get_rotation(nest, feeder)
    v = feeder - nest
    α = -atan(v[2], v[1]) - π/2
    rot = LinearMap(Angle2d(α))
    rot, α
end

(p::LinearMap{Angle2d{Float64}})(x::Missing) = missing

# LinearMap{Angle2d{Float64}}(x::Missing) = missing
function rotate!(x::Common)
    rot, α = get_rotation(x.nest, x.feeder)
    x.nest = rot(x.nest)
    x.feeder = rot(x.feeder) 
    x.track.coords .= rot.(x.track.coords)
    x.track.direction .-= α
    x.pellet.xy .= rot.(x.pellet.xy)
    x.originalnest = rot(x.originalnest) 
end

function center2!(x::Common, c)
    x.nest -= c
    x.feeder -= c
    for i in eachindex(x.track.coords)
        x.track.coords[i] -= c
    end
    for i in eachindex(x.pellet)
        x.pellet[i].xy -= c
    end
    if !ismissing(x.originalnest)
        x.originalnest -= c
    end
end

function plottrack(template_tex, r)

    p = @pgf Axis(
                  {smooth, legend_style =
                   {
                    at = Coordinate(1.15, 0.5),
                    anchor = "west",
                    legend_columns = 1,
                   },
                   xmajorgrids,
                   ymajorgrids,
                   "ytick distance=25",
                   "xtick distance=25",
                   axis_equal,
                   scale_only_axis, 
                   xlabel = "X (cm)",
                   ylabel = "Y (cm)",
                  },
                  PlotInc({only_marks}, Coordinates([Tuple(r.feeder)])),
                  LegendEntry("feeder"),
                  PlotInc({no_markers}, Coordinates(Tuple.(r.homing))),
                  LegendEntry("homing"),
                  PlotInc({only_marks}, Coordinates([Tuple(r.turningpoint)])),
                  LegendEntry("turning point"),
                  PlotInc({no_markers}, Coordinates(Tuple.(r.searching))), 
                  LegendEntry("searching"),
                  PlotInc({only_marks}, Coordinates([Tuple(r.searchcenter)])),
                  LegendEntry("search center")
                 );

    if !isempty(r.pellet) 
        @pgf push!(p, PlotInc({only_marks}, Coordinates(Tuple.(r.pellet.xy))), LegendEntry("pellet"))
    end
    @pgf push!(p, PlotInc({only_marks}, Coordinates([Tuple(r.nest)])), LegendEntry("nest"));
    if !ismissing(r.originalnest)
        @pgf push!(p, PlotInc({only_marks}, Coordinates([Tuple(r.originalnest)])), LegendEntry("original nest"))
    end
    name = tempname()*".tikz"
    pgfsave(name, p)
    replace(template_tex, "{{track}}" => name)
end


distance(x::Common, from::Symbol, to::Symbol) = round(Int, norm(getproperty(x, from) .- getproperty(x, to)))

getthings(x::Common{Missing}) = isempty(x.pellet) ? (:feeder, :turningpoint, :searchcenter, :nest) : (:feeder, :turningpoint, :searchcenter, :nest, :pellet1)
getthings(x::Common{T}) where {T} = isempty(x.pellet) ? (:feeder, :turningpoint, :searchcenter, :nest, :originalnest) : (:feeder, :turningpoint, :searchcenter, :nest, :originalnest, :pellet1)

function getdistancetable(x::Common)
    things = getthings(x)
    rows = Vector{Vector{String}}()
    for (from, to) in combinations(things, 2)
        push!(rows, string.([from, to, distance(x, from, to)]))
    end
    distancestable = latex_tabular(String, Tabular("llr"),
                                   [Rule(:top),
                                    ["From", "To", "cm"],
                                    Rule(:mid),
                                    rows...,
                                    Rule(:bottom)])
end


function plotdirection(template_tex, r)
    t = time(r)
    tl = range(0, stop = t[end], length = 5length(t))
    d = rad2deg.(r.track.direction .- π)
    itp = interpolate((t, ), d, Gridded(Linear()))
    dl = itp.(tl)
    tpl = findfirst(x -> x ≥ t[r.track.tp], tl)
    p = @pgf PolarAxis(
                       {legend_style =
                        {
                         at = Coordinate(1.15, 0.5),
                         anchor = "west",
                         legend_columns = 1,
                        },
                        # axis_equal,
                        scale_only_axis, 
                        xlabel = "Direction (°)",
                        ylabel = "Time (min.)",
                       },
                       PlotInc({no_markers}, Coordinates(dl[1:tpl], tl[1:tpl])),
                       LegendEntry("homing"),
                       PlotInc({only_marks}, Coordinates([dl[tpl]], [tl[tpl]])),
                       LegendEntry("turning point"),
                       PlotInc({no_markers}, Coordinates(dl[tpl:end], tl[tpl:end])),
                       LegendEntry("searching")
                      )
    name = tempname()*".tikz"
    pgfsave(name, p)
    replace(template_tex, "{{direction}}" => name)
end

function plotpathlength(template_tex, r)
    t = time(r)
    pl = cumsum(r.track.distance)/100
    p = @pgf Axis(
                  {legend_style =
                   {
                    at = Coordinate(1.15, 0.5),
                    anchor = "west",
                    legend_columns = 1,
                   },
                   # axis_equal,
                   scale_only_axis, 
                   xlabel = "Time (min.)",
                   ylabel = "Path length (m)",
                  },
                  PlotInc({no_markers}, Coordinates(t[1:r.track.tp], pl[1:r.track.tp])),
                  LegendEntry("homing"),
                  PlotInc({only_marks}, Coordinates([t[r.track.tp]], [pl[r.track.tp]])),
                  LegendEntry("turning point"),
                  PlotInc({no_markers}, Coordinates(t[r.track.tp:end], pl[r.track.tp:end])),
                  LegendEntry("searching")
                 )
    name = tempname()*".tikz"
    pgfsave(name, p)
    replace(template_tex, "{{pathlength}}" => name)
end


function plotspeed(template_tex, r)

    t = time(r)
    s = r.track.distance/r.track.Δt
    p = @pgf Axis(
                  {
                   legend_style =
                   {
                    at = Coordinate(1.15, 0.5),
                    anchor = "west",
                    legend_columns = 1,
                   },
                   # axis_equal,
                   scale_only_axis, 
                   xlabel = "Time (min.)",
                   ylabel = "Speed (cm/s)",
                  },
                  PlotInc({no_markers}, Coordinates(t[1:r.track.tp], s[1:r.track.tp])),
                  LegendEntry("homing"),
                  PlotInc({only_marks}, Coordinates([t[r.track.tp]], [s[r.track.tp]])),
                  LegendEntry("turning point"),
                  PlotInc({no_markers}, Coordinates(t[r.track.tp:end], s[r.track.tp:end])),
                  LegendEntry("searching")
                 )


    name = tempname()*".tikz"
    pgfsave(name, p)
    template_tex = replace(template_tex, "{{speed}}" => name)

    p2 = @pgf Axis(
                  {colormap_name = "viridis", smooth, legend_style =
                   {
                    at = Coordinate(1.15, 0.5),
                    anchor = "west",
                    legend_columns = 1,
                   },
                   xmajorgrids,
                   ymajorgrids,
                   "ytick distance=25",
                   "xtick distance=25",
                   axis_equal,
                   scale_only_axis, 
                   xlabel = "X (cm)",
                   ylabel = "Y (cm)",
                   "colorbar horizontal",
                   colorbar_style={
                                   xticklabel_pos="right", xlabel = "Speed (cm/s)", at=Coordinate(0,1.1), anchor="north west"
                                  },
                  },
                  Plot(
                       {
                        mesh,
                        # shader="faceted interp",
                        point_meta = raw"\thisrow{s}",
                        line_width = 3,
                       },
                       Table(x = first.(r.track.coords), y = last.(r.track.coords), s = s)
                      ),
                  LegendEntry("track"),
                  PlotInc({only_marks}, Coordinates([Tuple(r.feeder)])),
                  LegendEntry("feeder"),
                  PlotInc({only_marks}, Coordinates([Tuple(r.turningpoint)])),
                  LegendEntry("turning point"),
                  PlotInc({only_marks}, Coordinates([Tuple(r.searchcenter)])),
                  LegendEntry("search center")
                 );
    if !isempty(r.pellet) 
        @pgf push!(p2, PlotInc({only_marks}, Coordinates(Tuple.(r.pellet.xy))), LegendEntry("pellet"))
    end
    @pgf push!(p2, PlotInc({only_marks}, Coordinates([Tuple(r.nest)])), LegendEntry("nest"));
    if !ismissing(r.originalnest)
        @pgf push!(p2, PlotInc({only_marks}, Coordinates([Tuple(r.originalnest)])), LegendEntry("original nest"))
    end




    name = tempname()*".tikz"
    pgfsave(name, p2)
    replace(template_tex, "{{trackspeed}}" => name)



end

function plotangularchange(template_tex, r)
    t = time(r)
    tl = range(0, stop = t[end-1], length = 1000)
    d = diff(rad2deg.(r.track.direction))
    itp = interpolate((t[1:end-1], ), d, Gridded(Linear()))
    dl = itp.(tl)
    tpl = findfirst(x -> x ≥ t[r.track.tp], tl)
    if isnothing(tpl)
        tpl = length(tl)
    end
    p = @pgf PolarAxis(
                       {legend_style =
                        {
                         at = Coordinate(1.15, 0.5),
                         anchor = "west",
                         legend_columns = 1,
                        },
                        # axis_equal,
                        scale_only_axis, 
                        xlabel = "Direction change (°)",
                        ylabel = "Time (min.)",
                        xmin = -90,
                        xmax = 90,
                       },
                       PlotInc({no_markers}, Coordinates(dl[1:tpl], tl[1:tpl])),
                       LegendEntry("homing"),
                       PlotInc({only_marks}, Coordinates([dl[tpl]], [tl[tpl]])),
                       LegendEntry("turning point"),
                       PlotInc({no_markers}, Coordinates(dl[tpl:end], tl[tpl:end])),
                       LegendEntry("searching")
                      )
    name = tempname()*".tikz"
    pgfsave(name, p)
    replace(template_tex, "{{angularchange}}" => name)
end


# time(x::Common, s::Symbol) = range(0, step = x.track.Δt/60, length = length(getfield(x.track, s)))
# time(x::Common, length::Int) = range(0, step = x.track.Δt/60, length = length)

time(x::Common) = range(0, step = x.track.Δt/60, length = length(x.track.coords))










function plotresult(r::Common, targetfile)

    template_tex = read("/home/yakir/dungProject/DungAnalyse/src/results.tex", String)

    template_tex = plottrack(template_tex, r)
    template_tex = plotdirection(template_tex, r)
    template_tex = plotspeed(template_tex, r)
    template_tex = plotangularchange(template_tex, r)
    template_tex = plotpathlength(template_tex, r)

    template_tex = replace(template_tex,  "{{distancestable}}" => getdistancetable(r))

    base = tempname()
    texfile = "$base.tex"
    write(texfile, template_tex)
    latex_success, log, latexcmd = PGFPlotsX.run_latex_once(texfile, latexengine(), vcat(PGFPlotsX.DEFAULT_FLAGS, PGFPlotsX.CUSTOM_FLAGS))
    if latex_success
        mv("$base.pdf", targetfile, force=true)
    else
        error("failed to compile latex file $base.tex")
    end
end


# r = last(first(trackdata)).runs[3].data
# rotate!(r)
# center2!(r, r.nest)
# plotresult(r, "a.pdf")
