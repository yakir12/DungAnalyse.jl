using StatsBase, StaticArrays, StructArrays, Dierckx, AngleBetweenVectors, LinearAlgebra

const ignorefirst = 10 # cm
const bigturn = π/3 # 60°
# const smallturn = π/93 # 60°
const s = 500

const Point = SVector{2, Float64}
point(x::Missing) = x
point(x::Instantaneous)= Point(x.data[1], x.data[2])

_getv(spl, k) = SVector{2, Float64}(derivative(spl, k))

function gettpindex(spl, ks)
    tp = ks[1]
    vlast = _getv(spl, ks[1])
    for k in Iterators.drop(ks, 1)
        v = _getv(spl, k)
        Δ = angle(vlast, v)
        tp = k
        Δ > bigturn && break
        vlast = v
    end
    return tp
end

function gettpknot(spl)
    ks = Dierckx.get_knots(spl)
    filter!(k -> norm(spl(k) - spl(0)) > ignorefirst, ks)
    tp2 = gettpindex(spl, ks)
    # return tp2
    tp1 = copy(tp2)
    for k in ks
        k == tp2 && break
        tp1 = k
    end
    tp1 += 0.1
    if tp1 < tp2
        main = _getv(spl, tp1)
        for t in tp2:-0.3:tp1
            v = _getv(spl, t)
            Δ = angle(main, v)
            Δ < bigturn && return t
        end
    end
    return tp2
end

mutable struct TimedPoint
    xy::Point
    t::Float64
end

const PointCollection = StructVector{TimedPoint}
pointcollection(x::Missing, t₀) = StructVector{TimedPoint}(undef, 0)
pointcollection(x, t₀) = StructVector(TimedPoint(Point(i[1], i[2]), i[3] - t₀) for i in eachrow(x.data))

struct Track
    coords::Vector{Point}
    t::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    tp::Int
    rawcoords::StructArray{TimedPoint}
end

function filterdance(xy, Δt)
    xy2 = [xy[1,:]]
    t = [0.0]
    for p in eachrow(xy)
        if norm(p - xy2[end]) > 4
            push!(xy2, p)
            push!(t, t[end] + Δt)
        else
            t[end] += Δt
        end
    end
    t .-= t[1]
    return t, hcat(xy2...)
end

function Track(x::Prolonged)
    xyt = !issorted(x.data[:, 3]) ? sortslices(x.data, dims = 1, lt = (x, y) -> isless(x[3], y[3])) : x.data
    Δt = mean(trim(diff(xyt[:, 3]), prop = 0.1))
    t, xy = filterdance(xyt[:,1:2], Δt)
    spl = ParametricSpline(t, xy; s = s, k = 2)
    tl = range(0.0, step = Δt, stop = t[end])
    xyl = Point.(spl.(tl))
    tp = gettpknot(spl)
    i = findfirst(≥(tp), tl)
    if isnothing(i)
        i = length(tl)
    end
    raw = pointcollection((data = xyt, ), xyt[1,3])
    Track(xyl, tl, i, raw)
end

homing(t::Track) = t.coords[1:t.tp]
searching(t::Track) = t.coords[t.tp:end]
searchcenter(t::Track) = mean(searching(t))
turningpoint(t::Track) = t.coords[t.tp]

