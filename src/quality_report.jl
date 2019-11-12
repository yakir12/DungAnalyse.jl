using PGFPlotsX, FileIO, StringBuilders, LaTeXTabulars

function getmozaik(n, w, h)
    ratio = w/h
    mh = ceil(Int, sqrt(n*ratio))
    nw = round(Int, mh/ratio)
    while nw*mh < n
        mh += 1
    end
    nw, mh
end

function errorcm(file, ϵ)
    pixel = Prolonged([0 0 0; ϵ 0 0])
    cm = calibrate(file, pixel)
    norm(diff(cm.data[:,1:2], dims = 1))
end

function PGFPlotsX.print_tex(::Type{String}, plot)
    io = IOBuffer()
    print_tex(io, plot)
    strip(String(take!(io)))
end

escape4latex(x) = replace(x, r"([#$%^&_{}~\\])" => s"\\\1")#SubstitutionString("\\\\\\1"))
# x = """# \$ % ^ & _ { } ~ \\ """
# escape4latex(x)

getcomments(c::Calibration) = latex_tabular(String, Tabular("l p{5cm}"),
                                            [Rule(:top),
                                             ["Source", "Comment"],
                                             Rule(:mid),
                                             ["Overall", escape4latex(c.comment)],
                                             ["Intrinsic", escape4latex(c.intrinsic.comment)],
                                             ["Video (intrinsic)", escape4latex(c.intrinsic.video.comment)],
                                             ["Extrinsic", escape4latex(c.extrinsic.comment)],
                                             ["Video (extrinsic)", escape4latex(c.extrinsic.video.comment)],
                                             Rule(:bottom)])
#=getcomments(c::Calibration) = latex_tabular(String, Tabular("l p{5cm}"),
                                            [Rule(:top),
                                             ["Source", "Comment"],
                                             Rule(:mid),
                                             ["Overall", "\\detokenize{$(c.comment)}"],
                                             ["Intrinsic", "\\detokenize{$(c.intrinsic.comment)}"],
                                             ["Video (intrinsic)", "\\detokenize{$(c.intrinsic.video.comment)}"],
                                             ["Extrinsic", "\\detokenize{$(c.extrinsic.comment)}"],
                                             ["Video (extrinsic)", "\\detokenize{$(c.extrinsic.video.comment)}"],
                                             Rule(:bottom)])=#

getcomments(c::Calibration{Missing, T}) where {T} = latex_tabular(String, Tabular("l p{5cm}"),
                                                                  [Rule(:top),
                                                                   ["Source", "Comment"],
                                                                   Rule(:mid),
                                                                   ["Overall", escape4latex(c.comment)],
                                                                   ["Extrinsic", escape4latex(c.extrinsic.comment)],
                                                                   ["Video (extrinsic)", escape4latex(c.extrinsic.video.comment)],
                                                                   Rule(:bottom)])

#=getcomments(c::Calibration{Missing, T}) where {T} = latex_tabular(String, Tabular("l p{5cm}"),
                                                                  [Rule(:top),
                                                                   ["Source", "Comment"],
                                                                   Rule(:mid),
                                                                   ["Overall", "\\detokenize{$(c.comment)}"],
                                                                   ["Extrinsic", "\\detokenize{$(c.extrinsic.comment)}"],
                                                                   ["Video (extrinsic)", "\\detokenize{$(c.extrinsic.video.comment)}"],
                                                                   Rule(:bottom)])=#

function getintrinsicplot(path, w, h)
    intrinsic = [joinpath(path, file) for file in readdir(path) if "extrinsic.png" ≠ file]
    n = length(intrinsic)
    nw, mh = getmozaik(n, w, h)
    gp = @pgf GroupPlot(
                        {
                         group_style =
                         {
                          group_size = "$nw by $mh"#, vertical_sep = "1mm", horizontal_sep = "1mm"
                         },
                         width = "\\linewidth/$nw", height = "\\linewidth/$mh", enlargelimits=false, axis_equal_image, hide_axis
                        })
    @pgf for imgname in intrinsic
        push!(gp, {}, Plot(Graphics({xmin=1,xmax=w,ymin=1,ymax=h}, imgname)))
    end
    name = tempname()*".tikz"
    pgfsave(name, gp)
    name
end
function getextrinsicplot(path, w, h)
    extrinsic = joinpath(path, "extrinsic.png")
    @pgf p = Axis({
                   enlargelimits=false, axis_equal_image, hide_axis#, width = "$(textwidth)mm"
                  }, Plot(Graphics({xmin=1,xmax=w,ymin=1,ymax=h}, extrinsic)))
    name = tempname()*".tikz"
    pgfsave(name, p)
    name
end

function _getplots(c::Calibration, calibfile, ϵpixel)
    path = joinpath(coffeesource, "calibration_images", string(hash(c)))
    h, w = size(FileIO.load(joinpath(path, "extrinsic.png")))
    extrinsicplot = getextrinsicplot(path, w, h)
    ϵcm = errorcm(calibfile, ϵpixel)
    errorstable = latex_tabular(String, Tabular("lll"),
                                [Rule(:top),
                                 ["", "pixel", "cm"],
                                 Rule(:mid),
                                 ["Mean erros", round(ϵpixel, digits = 3), round(ϵcm, digits = 3)],
                                 Rule(:bottom)])
    path, w, h, extrinsicplot, errorstable
end

function getplots(c::Calibration{Missing, T}, calibfile, ϵpixel) where {T}
    path, w, h, extrinsicplot, errorstable =  _getplots(c, calibfile, ϵpixel)
    commentstable = getcomments(c)
    extrinsicplot, errorstable, commentstable, false
end
function getplots(c::Calibration, calibfile, ϵpixel)
    path, w, h, extrinsicplot, errorstable =  _getplots(c, calibfile, ϵpixel)
    intrinsicplot = getintrinsicplot(path, w, h)
    commentstable = getcomments(c)
    extrinsicplot, errorstable, commentstable, true, intrinsicplot
end

function calibrationquality!(template_tex, c, calibfile, ϵpixel, pois, calibnumber)
    template_tex = replace(template_tex, "{{pois}}" => pois)
    template_tex = replace(template_tex, "{{calibnumber}}" => calibnumber)
    for (old, new) in zip(("{{extrinsicplot}}", "{{errorstable}}", "{{calibrationcommentstable}}", "{{isintrinsic}}", "{{intrinsicplot}}"), getplots(c, calibfile, ϵpixel))
        template_tex = replace(template_tex, old => print_tex(String, new))
    end
    template_tex
end


function getcomments(x::Dict{Symbol, POI{T}}) where {T}
    rows = Vector{Vector{String}}()
    for (k, v) in x
        append!(rows, [[string(k), "Overall ", escape4latex(v.data.comment)], [string(k), "Video ", escape4latex(v.data.video.comment)]])
    end
    latex_tabular(String, Tabular("l l p{5cm}"),
                  [Rule(:top),
                   ["POI", "Source", "Comment"],
                   Rule(:mid),
                   rows...,
                   Rule(:bottom)])
end


_isinstantaneous(_::POI{C, Temporal{V, I}}) where {C <: Calibration, V <: AbstractTimeLine, I <: Instantaneous} = true
_isinstantaneous(_) = false

function clickquality(template_tex, temporalpois, pixelpois)
    pois = filter(_isinstantaneous∘last, temporalpois)
    n = length(pois)
    imgname = tempname()*".jpg"
    extract(imgname, last(first(pois)).data, coffeesource)
    h, w = size(FileIO.load(imgname))
    nw, mh = getmozaik(n, w, h)
    gp = @pgf GroupPlot(
                        {
                         group_style =
                         {
                          group_size="$nw by $mh"#, vertical_sep = "1mm", horizontal_sep = "1mm"
                         },
                         width = "\\linewidth/$nw", height = "\\linewidth/$mh", enlargelimits=false, axis_equal_image, hide_axis, y_dir = "reverse" 
                        });
    @pgf for (poitype, p) in pois
        imgname = tempname()*".jpg"
        extract(imgname, p.data, coffeesource)
        f1 = Plot(Graphics({xmin=1,xmax=w,ymin=1,ymax=h}, imgname))
        x, y, t = pixelpois[poitype].data.data
        f2 = Plot({only_marks, "red", mark_size="0.1pt"}, Table([x], [y]))
        α = atand(y - h/2, w/2 - x)
        push!(gp, {}, f1, f2, "\\node[inner sep=2, pin={[pin edge={<-, red,thick}, fill = white, draw = red]$α:$poitype}] at ($x, $y) {};")
    end
    name = tempname()*".tikz"
    pgfsave(name, gp)
    template_tex = replace(template_tex,  "{{clickquality}}" => name)
    replace(template_tex,  "{{clickcomments}}" => print_tex(String, getcomments(temporalpois)))
end

plot(x::Instantaneous{Array{Float64,2}}) = @pgf PlotInc({only_marks}, Table(x.data[1:1], x.data[2:2]))
plot(x::Prolonged{Array{Float64,2}}) = @pgf PlotInc({no_markers}, Table(x.data[:,1], x.data[:,2]))

function calibratedtrackquality(template_tex, pixelpois, cmpois)
    @pgf gp = GroupPlot(
                        {legend_style =
                         {
                          at = Coordinate(0.5, -0.15),
                          anchor = "north",
                          legend_columns = -1,
                          draw="none"
                         },
                         group_style =
                         {
                          group_size="2 by 1",
                         },
                         xmajorgrids, ymajorgrids, width = "\\linewidth/2", height = "\\linewidth/2", axis_equal
                        })
    @pgf push!(gp, {title = "Raw", xlabel = "X (pixel)", ylabel = "Y (pixel)"})#, legend_to_name = "grouplegend"})
    for (k, v) in pixelpois
        push!(gp, plot(v.data), LegendEntry(string(k)))
    end
    @pgf push!(gp, {title = "Calibrated", "yticklabel pos=right", xlabel = "X (cm)", ylabel = "Y (cm)"})
    for (k, v) in cmpois
        push!(gp, plot(v))
    end
    name = tempname()*".tikz"
    pgfsave(name, gp)
    replace(template_tex,  "{{calibratedpois}}" => name)
end

function smoothquality(template_tex, cmtrack, smtrack)
    sm = vcat(smtrack.homing, smtrack.searching)
    p = @pgf Axis(
                  {legend_style =
                   {
                    at = Coordinate(0.5, -0.15),
                    anchor = "north",
                    legend_columns = -1,
                    draw="none"
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
                  PlotInc({only_marks, mark_size=2, opacity = 0.25, draw_opacity=0}, Table(cmtrack[:,1], cmtrack[:,2])),
                  PlotInc({thick, no_markers}, Table(first.(sm), last.(sm))),
                  Legend("calibrated", "smoothed")
                 )
    name = tempname()*".tikz"
    pgfsave(name, p)
    replace(template_tex, "{{smoothquality}}" => name)
end


function turningpointquality(template_tex, track)
    nsearching = min(length(track.searching), 25)
    sm = vcat(track.homing, track.searching[1:nsearching])

    p = @pgf Axis(
                  {smooth, legend_style =
                   {
                    at = Coordinate(0.5, -0.15),
                    anchor = "north",
                    legend_columns = -1,
                    draw="none"
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
                  PlotInc({
                           no_markers,
                           mesh, 
                           """colormap={}{
                           color(0cm)=(black!10);
                           color(1cm)=(black);
                           }""",
                           ultra_thick,
                          }, Table({
                                    point_meta = raw"\thisrow{c}"
                                   },
                                   x = first.(sm), y = last.(sm), c = range(0, step = track.Δt, length = length(sm)))),
                  PlotInc({only_marks}, Table(track.homing[end][1:1], track.homing[end][2:2])),
                  Legend(["Track", "Turning point"])
                 )
    name = tempname()*".tikz"
    pgfsave(name, p)
    replace(template_tex, "{{turningpointquality}}" => name)
end

function plotquality(temporalpois, pixelpois, nameerror, cmpois, track, runcomment, targetfile)
    c2pois = Dict{Calibration, String}()
    for (k,v) in temporalpois
        if haskey(c2pois, v.calib)
            c2pois[v.calib] *= ", $k"
        else
            c2pois[v.calib] = string(k)
        end
    end

    io = IOBuffer()
    for (i, (c, v)) in enumerate(c2pois)
        calib_template = read("/home/yakir/dungProject/DungAnalyse/src/calibrations.tex", String)
        println(io, calibrationquality!(calib_template, c, nameerror[c]..., v, i))
    end
    calibrations = String(take!(io))

    template_tex = read("/home/yakir/dungProject/DungAnalyse/src/qualityreport.tex", String)

    template_tex = replace(template_tex,  "{{calibrations}}" => calibrations)

    template_tex = clickquality(template_tex, temporalpois, pixelpois)

    template_tex = calibratedtrackquality(template_tex, pixelpois, cmpois)

    template_tex = smoothquality(template_tex, cmpois[:track].data, track)

    template_tex = turningpointquality(template_tex, track)

    template_tex = replace(template_tex,  "{{runcomment}}" => runcomment)

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
