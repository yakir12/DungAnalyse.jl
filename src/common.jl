using Unitful, Statistics, StaticArrays, Rotations, CoordinateTransformations

function getdata(data)
    feeder = point(get(data, :feeder, missing))
    nest = point(get(data, :nest, missing))
    track = Track(data[:track])
    pellet = pointcollection(get(data, :pellet, missing), data[:track].data[1,3])
    feeder, nest, track, pellet
end

function common(x)
    feeder, nest, track, pellet = getdata(x.data)
    fictive_nest = getfictive_nest(x, feeder, nest)
    Common(feeder, nest, track, pellet, fictive_nest)
end

function getfictive_nest(x, feeder::Point, nest::Missing)
    south = point(x.data[:south])
    north = point(x.data[:north])
    nest2feeder = getnest2feeder(x)
    azimuth = getazimuth(x)
    v = north - south
    α = atan(v[2], v[1]) + azimuth - π
    u = Point(cos(α), sin(α))
    return feeder + u*nest2feeder
end

function getfictive_nest(x, feeder::Missing, nest::Point)
    dropoff = getdropoff(x.data)
    pickup = getfeeder(point(x.data[:guess]), convert_displacement(x.metadata.setup[:displacement]), nest, dropoff, getnest2feeder(x))
    v = dropoff - pickup
    return nest + v
end

function getfictive_nest(x, feeder::Point, nest::Point)
    pickup = getpickup(x.data)
    ismissing(pickup) && return nest
    dropoff = getdropoff(x.data)
    v = dropoff - pickup
    return nest + v
end

function convert_displacement(d)
    m = match(r"\((.+),(.+)\)", d)
    x, y = parse.(Int, m.captures)
    point(x, y)
end

function calculatec(guess, displacement, nest, dropoff)
    v = dropoff - nest
    α = π/2 - atan(v[2], v[1])
    t = LinearMap(Angle2d(α)) ∘ Translation(-nest)
    ṫ = inv(t)
    ab = norm(displacement)
    bc, ac = displacement
    cy = (ab^2 + ac^2 - bc^2)/2ab
    Δ = sqrt(ac^2 - cy^2)
    c = [ṫ([i*Δ, cy]) for i in (-1, 1)]
    l = norm.(c .- Ref(guess))
    _, i = findmin(l)
    c[i]
end

function getfeeder(guess, displacement, nest, dropoff, nest2feeder)
    c = calculatec(guess, displacement, nest, dropoff)
    @show guess, c
    u = normalize(nest - c)
    @show nest2feeder
    nest + nest2feeder*u
end

getpickup(d) = haskey(d, :pickup) ? point(d[:pickup]) : 
               haskey(d, :initialfeeder) ? point(d[:initialfeeder]) : 
               haskey(d, :rightdowninitial) ? mean(point(d[k]) for k in (:rightdowninitial, :leftdowninitial, :rightupinitial, :leftupinitial)) :
               missing
getdropoff(d) = haskey(d, :dropoff) ? point(d[:dropoff]) : 
                haskey(d, :rightdownfinal) ? mean(point(d[k]) for k in (:rightdownfinal, :leftdownfinal, :rightupfinal, :leftupfinal)) :
                haskey(d, :feeder) ? point(d[:feeder]) : 
                missing

getnest2feeder(x) = haskey(x.data, :nestbefore) ? norm(x.data[:nestbefore] - x.data[:feederbefore]) :
                    haskey(x.metadata.setup, :nest2feeder) ?  _getvalueunit(x.metadata.setup[:nest2feeder], u"cm") :
                    missing
function anglebetween(north, south, nest, feeder)
    v = normalize(north - south)
    u = normalize(nest - feeder)
    acos(v ⋅ u)
    # atan(v[2], v[1]) - atan(u[2], u[1])
end
getazimuth(x) = haskey(x.data, :southbefore) ? anglebetween(x.data[:northbefore], x.data[:southbefore], x.data[:nestbefore], x.data[:feederbefore]) :
                haskey(x.metadata.setup, :azimuth) ?  _getvalueunit(x.metadata.setup[:azimuth], u"°") :
                    missing
                    
function _getvalueunit(txt, default)
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

######################### DungMethod methods ###########

# common(x) = Common(x)

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

