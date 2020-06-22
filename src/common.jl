using Unitful, Statistics, StaticArrays, Rotations, CoordinateTransformations, LinearAlgebra

function getmissingfeeder(guess, displacement, nest, dropoff, nest2feeder)
    c = calculatec(guess, displacement, nest, dropoff)
    u = normalize(nest - c)
    return nest + nest2feeder*u
end

getfeeder(x, nest, dropoff, nest2feeder) = haskey(x.data, :initialfeeder) ? point(x.data[:initialfeeder]) :
haskey(x.data, :feeder) ? point(x.data[:feeder]) :
                  getmissingfeeder(point(x.data[:guess]), convert_displacement(x.metadata.setup[:displacement]), nest, dropoff, nest2feeder)

getnest(data) = get(data, :nest, missing)

getpickup(data, ::Missing, _) = missing
getpickup(data, _, feeder) = haskey(data, :rightdowninitial) ? mean(point(data[k]) for k in (:rightdowninitial, :leftdowninitial, :rightupinitial, :leftupinitial)) : 
                             haskey(data, :initialfeeder) ? data[:initialfeeder] : 
                             get(data, :pickup, feeder)

# getdropoff(data, ::Nothing) = nothing
getdropoff(data) = haskey(data, :rightdownfinal) ? mean(point(data[k]) for k in (:rightdownfinal, :leftdownfinal, :rightupfinal, :leftupfinal)) : 
                      haskey(data, :dropoff) ? data[:dropoff] :
                      data[:feeder]

getnest2feeder(x) = haskey(x.data, :nestbefore) ? norm(x.data[:nestbefore] - x.data[:feederbefore]) :
                    haskey(x.metadata.setup, :nest2feeder) ?  _getvalueunit(x.metadata.setup[:nest2feeder], u"cm") :
                    missing

function getdata(x)
    nest = point(getnest(x.data))
    track = Track(x.data[:track])
    if haskey(x.metadata.setup, :turningpoint)
        track.tp = x.metadata.setup[:turningpoint]
    end
    pellet = pointcollection(get(x.data, :pellet, missing), x.data[:track].data[1,3])
    dropoff = point(getdropoff(x.data))
    nest2feeder = getnest2feeder(x)
    feeder = getfeeder(x, nest, dropoff, nest2feeder)
    pickup = point(getpickup(x.data, nest, feeder))
    feeder, nest, track, pellet, pickup, dropoff, nest2feeder
end

function common(x)
    feeder, nest, track, pellet, pickup, dropoff, nest2feeder = getdata(x)
    fictive_nest = getfictive_nest(x, pickup, nest, dropoff, nest2feeder)
    feeder, nest, track, pellet, fictive_nest, pickup, dropoff = fix(feeder, nest, track, pellet, fictive_nest, pickup, dropoff, nest2feeder)
    Common(feeder, nest, track, pellet, fictive_nest, pickup, dropoff)
end

getfictive_nest(x, pickup::Nothing, nest::Point, dropoff::Nothing, _) = nest
getfictive_nest(x, pickup::Point, nest::Point, dropoff::Point, _) = nest + dropoff - pickup
function getfictive_nest(x, pickup::Missing, nest::Missing, dropoff::Point, nest2feeder)
    south = point(x.data[:south])
    north = point(x.data[:north])
    v = north - south
    azimuth = getazimuth(x)
    α = atan(v[2], v[1]) + azimuth - π
    u = Point(cos(α), sin(α))
    return dropoff + u*nest2feeder
end

fix(feeder, nest::Missing, track, pellet, fictive_nest, pickup, dropoff, nest2feeder) = (feeder, nest, track, pellet, fictive_nest, pickup, dropoff)
fix(feeder::Missing, nest, track, pellet, fictive_nest, pickup, dropoff, nest2feeder) = (feeder, nest, track, pellet, fictive_nest, pickup, dropoff)
function fix(feeder, nest, track, pellet, fictive_nest, pickup, dropoff, nest2feeder)
    nest2feeder2 = norm(nest - feeder)
    if abs(nest2feeder2 - nest2feeder) > 10
        @info "calculated distance between nest and feeder is more than 10 cm different than the reported distance; applying a correction"
        r = nest2feeder/nest2feeder2
        feeder *= r
        nest *= r
        track.coords .*= r
        track.rawcoords.xy .*= r
        pellet.xy .*= r
        fictive_nest *= r
        pickup *= r
        dropoff *= r
    end
    return feeder, nest, track, pellet, fictive_nest, pickup, dropoff
end

function convert_displacement(d)
    m = match(r"\((.+),(.+)\)", d)
    x, y = parse.(Int, m.captures)
    Point(x, y)
end

function calculatec(guess, displacement, nest, dropoff)
    v = dropoff - nest
    α = π/2 - atan(v[2], v[1])
    t = LinearMap(Angle2d(α)) ∘ Translation(-nest)
    ṫ = inv(t)
    ab = norm(displacement)
    bc², ac² = displacement.^2
    cy = (ab^2 + ac² - bc²)/2ab
    Δ = sqrt(ac² - cy^2)
    c = [ṫ([i*Δ, cy]) for i in (-1, 1)]
    l = norm.(c .- Ref(guess))
    _, i = findmin(l)
    c[i]
end

function anglebetween(north, south, nest, feeder)
    v = normalize(north - south)
    u = normalize(nest - feeder)
    acos(v ⋅ u)
    # atan(v[2], v[1]) - atan(u[2], u[1])
end
getazimuth(x) = haskey(x.data, :southbefore) ? anglebetween(x.data[:northbefore], x.data[:southbefore], x.data[:nestbefore], x.data[:feederbefore]) :
                haskey(x.metadata.setup, :azimuth) ?  _getvalueunit(x.metadata.setup[:azimuth], u"°") :
                    missing
                    
_getvalueunit(x::Real, default) = Float64(x)
function _getvalueunit(txt::AbstractString, default)
    m = match(r"^(\d+)\s*(\D*)", txt)
    d, txtu = m.captures
    u = try
        _u = getfield(Unitful, Symbol(txtu))
        @assert _u isa Unitful.FreeUnits
        _u
    catch
        default
    end
    Float64(ustrip(uconvert(default, parse(Int, d)*u)))
end

######################### END ######################

function get_rotation(nest, feeder)
    v = feeder - nest
    α = -atan(v[2], v[1])# - π/2
    rot = LinearMap(Angle2d(α))
    rot, α
end

(p::LinearMap{Angle2d{Float64}})(x::Missing) = missing

# LinearMap{Angle2d{Float64}}(x::Missing) = missing
function rotate!(x)
    rot, α = get_rotation(x.nest, x.feeder)
    x.nest = rot(x.nest)
    x.feeder = rot(x.feeder) 
    x.track.coords .= rot.(x.track.coords)
    # x.track.direction .+= α
    x.pellet.xy .= rot.(x.pellet.xy)
    x.originalnest = rot(x.originalnest) 
end

function rotate2!(x)
    rot, α = get_rotation(c, x.feeder)
    x.nest = rot(x.nest)
    x.feeder = rot(x.feeder) 
    x.track.coords .= rot.(x.track.coords)
    # x.track.direction .+= α
    x.pellet.xy .= rot.(x.pellet.xy)
    x.originalnest = rot(x.originalnest) 
end

function center2!(x)
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

