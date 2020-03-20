using StaticArrays, StatsBase, Dierckx, AngleBetweenVectors, OnlineStats, LinearAlgebra

const ignorefirst = 10
const deviatingangle = π/3
const tpangle = π/2
const maxattempt = 3

const Point = SVector{2, Float64}
point(x::Missing) = x
point(x::Instantaneous)= Point(x.data[1], x.data[2])

_getv(spl, k) = SVector{2, Float64}(derivative(spl, k))

function gettpi(spl, ks)
    direction = SVector{2, Mean}(Mean(), Mean())
    v = _getv(spl, ks[1])
    fit!.(direction, v)
    tp = 1
    attempts = 1
    nk = length(ks)
    for i in 2:nk
        v = _getv(spl, ks[i])
        Δ = angle(mean.(direction), v)
        if Δ < deviatingangle
            fit!.(direction, v)
            tp = i + 1
        elseif Δ < tpangle
            attempts += 1
            if attempts > maxattempt
                return tp
            end
        else
            return tp
        end
    end
    return nk
end
function gettp(spl)
    ks = Dierckx.get_knots(spl)
    filter!(xy -> norm(spl(xy) - spl(0)) > ignorefirst, ks)
    tp = gettpi(spl, ks)
    ks[tp]
end

function _find_close2tp(xy, tp)
    m = Inf
    for (i, p) in enumerate(xy)
        _m = norm(p - tp)
        if _m ≤ m
            m = _m
        else
            return i
        end
    end
    return length(xy)
end

struct Track
    coords::Vector{Point}
    t::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    tp::Int
end

function Track(x::Prolonged)
    xyt = !issorted(x.data[:, 3]) ? sortslices(x.data, dims = 1, lt = (x, y) -> isless(x[3], y[3])) : x.data
    Δt = mean(trim(diff(xyt[:, 3]), prop = 0.1))
    t = range(0.0, step = Δt, length = size(xyt, 1))
    spl = ParametricSpline(t, xyt[:, 1:2]'; s = 500)
    xy = Point.(spl.(t))
    tp = gettp(spl)
    i = _find_close2tp(xy, tp)
    Track(xy, t, i)
end

homing(t::Track) = t.coords[1:t.tp]
searching(t::Track) = t.coords[t.tp:end]
searchcenter(t::Track) = mean(searching(t))
turningpoint(t::Track) = t.coords[t.tp]
