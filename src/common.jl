using Unitful, Statistics, StaticArrays, StructArrays, Rotations, CoordinateTransformations

function getdata(x)
    track = Track(x[:track])
    feeder = point(get(x, :feeder, x[:track].data[1,1:2]))
    pellet = pointcollection(get(x, :pellet, missing), x[:track].data[1,3])
    feeder, track, pellet
end
abstract type DungMethod end
struct ClosedNest <: DungMethod 
    feeder::Point
    nest::Point
    track::Track
    pellet::PointCollection
end
function ClosedNest(x) 
    feeder, track, pellet = getdata(x.data)
    nest = point(x.data[:nest])
    ClosedNest(feeder, nest, track, pellet)
end
struct Transfer <: DungMethod
    feeder::Point
    track::Track
    pellet::PointCollection
    south::Point
    north::Point
    nest2feeder::Float64
    azimuth::Float64
end
function Transfer(x) 
    feeder, track, pellet = getdata(x.data)
    south = point(x.data[:south])
    north = point(x.data[:north])
    d, u = split(string(x.metadata.setup[:nest2feeder]))
    nest2feeder = Float64(ustrip(uconvert(Unitful.cm, parse(Int, d)*getfield(Unitful, Symbol(u)))))
    d, u = split(string(x.metadata.setup[:azimuth]))
    azimuth = Float64(ustrip(uconvert(Unitful.rad, parse(Int, d)*getfield(Unitful, Symbol(u)))))
    Transfer(feeder, track, pellet, south, north, nest2feeder, azimuth)
end
struct TransferNest <: DungMethod
    feeder::Point
    track::Track
    pellet::PointCollection
    south::Point
    north::Point
    nest2feeder::Float64
    azimuth::Float64
    originalnest::Point
end
function TransferNest(x) 
    y = Transfer(x)
    originalnest = point(x.data[:originalnest])
    TransferNest(y.feeder, y.track, y.pellet, y.south, y.north, y.nest2feeder, y.azimuth, originalnest)
end
Transfer(x::TransferNest) = Transfer(x.feeder, x.track, x.pellet, x.south, x.north, x.nest2feeder, x.azimuth)
struct TransferNestBelen <: DungMethod 
    feeder::Point
    track::Track
    pellet::PointCollection
    southbefore::Point
    northbefore::Point
    feederbefore::Point
    nestbefore::Point
    south::Point
    north::Point
end
function TransferNestBelen(x) 
    feeder, track, pellet = getdata(x.data)
    southbefore = point(x.data[:southbefore])
    northbefore = point(x.data[:northbefore])
    feederbefore = point(x.data[:feederbefore])
    nestbefore = point(x.data[:nestbefore])
    south = point(x.data[:south])
    north = point(x.data[:north])
    TransferNestBelen(feeder, track, pellet, rightdowninitial, leftdowninitial, rightupinitial, leftupinitial, rightdownfinal, leftdownfinal, rightupfinal, leftupfinal)
end
struct DawaySandpaper <: DungMethod
    feeder::Point
    nest::Point
    track::Track
    pellet::PointCollection
    rightdowninitial::Point
    leftdowninitial::Point
    rightupinitial::Point
    leftupinitial::Point
    rightdownfinal::Point
    leftdownfinal::Point
    rightupfinal::Point
    leftupfinal::Point
end
function DawaySandpaper(x) 
    feeder, track, pellet = getdata(x.data)
    nest = point(x.data[:nest])
    rightdowninitial = point(x.data[:rightdowninitial])
    leftdowninitial = point(x.data[:leftdowninitial])
    rightupinitial = point(x.data[:rightupinitial])
    leftupinitial = point(x.data[:leftupinitial])
    rightdownfinal = point(x.data[:rightdownfinal])
    leftdownfinal = point(x.data[:leftdownfinal])
    rightupfinal = point(x.data[:rightupfinal])
    leftupfinal = point(x.data[:leftupfinal])
    DawaySandpaper(feeder, nest, track, pellet, rightdowninitial, leftdowninitial, rightupinitial, leftupinitial, rightdownfinal, leftdownfinal, rightupfinal, leftupfinal)
end
struct DawayNest <: DungMethod
    feeder::Point
    nest::Point
    track::Track
    pellet::PointCollection
    pickup::Point
end
function DawayNest(x) 
    feeder, track, pellet = getdata(x.data)
    nest = point(x.data[:nest])
    pickup = point(x.data[:pickup])
    DawayNest(feeder, nest, track, pellet, pickup)
end
struct Daway <: DungMethod
    feeder::Point
    nest::Point
    track::Track
    pellet::PointCollection
    initialfeeder::Point
end
function Daway(x) 
    feeder, track, pellet = getdata(x.data)
    nest = point(x.data[:nest])
    initialfeeder = point(x.data[:initialfeeder])
    Daway(feeder, nest, track, pellet, initialfeeder)
end

######################### DungMethod methods ###########

DungMethod(x, displace_location, displace_direction::Missing, transfer::Missing, nest_coverage::Missing) = error("unidentified experimental setup")
DungMethod(x, displace_location::Missing, displace_direction::Missing, transfer::Missing, nest_coverage) = ClosedNest(x)
function DungMethod(x, displace_location::Missing, displace_direction::Missing, transfer, nest_coverage)
    if x.metadata.setup[:person] == "belen"
        TransferNestBelen(x)
    else
        if transfer == "back"
            TransferNest(x)
        elseif transfer == "far"
            Transfer(x)
        else
            error("unidentified experimental setup")
        end
    end
end
function DungMethod(x, displace_location, displace_direction, transfer::Missing, nest_coverage) 
    if displace_location == "feeder"
        if x.metadata.setup[:person] == "belen" 
            DawaySandpaper(x) 
        else
            Daway(x)
        end
    elseif displace_location == "nest"
        DawayNest(x)
    else
        error("unidentified experimental setup")
    end
end

######################### Common methods ###########

mutable struct Common{N}
    feeder::Point
    nest::Point
    track::Track
    pellet::PointCollection
    originalnest::N
end
Common(x::ClosedNest) = Common(x.feeder, x.nest, x.track, x.pellet, x.nest)
nest(x::Common) = x.nest
turning(x::Common) = x.track.homing[end]
originalnest(x::Common) = x.originalnest

function Common(x::TransferNestBelen)
    v = x.northbefore - x.southbefore
    u = x.nestbefore - x.feederbefore 
    azimuth = atan(v[2], v[1]) - atan(u[2], u[1])
    nest2feeder = norm(x.nestbefore - x.feederbefore)
    v = x.north - x.south
    α = atan(v[2], v[1]) + azimuth
    u = Point(cos(α), sin(α))
    nest = x.feeder + u*nest2feeder
    Common(x.feeder, nest, x.track, x.pellet, missing)
end

function Common(x::Transfer)
    v = x.north - x.south
    α = atan(v[2], v[1]) + x.azimuth - π
    u = Point(cos(α), sin(α))
    nest = x.feeder + u*x.nest2feeder
    Common(x.feeder, nest, x.track, x.pellet, missing)
end

function Common(x::TransferNest)
    y = Common(Transfer(x))
    Common(y.feeder, y.nest, y.track, y.pellet, x.originalnest)
end

function Common(x::DawaySandpaper)
    originalnest = x.nest
    initial = mean(getproperty(x, k) for k in [:rightdowninitial, :leftdowninitial, :rightupinitial, :leftupinitial])
    final = mean(getproperty(x, k) for k in [:rightdownfinal, :leftdownfinal, :rightupfinal, :leftupfinal])
    v = final - initial
    nest = originalnest + v
    _feeder = x.feeder
    feeder = _feeder + v
    Common(feeder, nest, x.track, x.pellet, originalnest)
end

function Common(x::DawayNest)
    originalnest = x.nest
    feeder = x.feeder
    v = originalnest - x.pickup
    nest = feeder + v
    Common(feeder, nest, x.track, x.pellet, originalnest)
end

function Common(x::Daway)
    originalnest = x.nest
    v = x.feeder - x.initialfeeder
    nest = originalnest + v
    Common(x.feeder, nest, x.track, x.pellet, originalnest)
end

######################### END ######################

Common(x) = Common(DungMethod(x, get(x.metadata.setup, :displace_location, missing), get(x.metadata.setup, :displace_direction, missing), get(x.metadata.setup, :transfer, missing), get(x.metadata.setup, :nest_coverage, missing)))

function get_rotation(nest, feeder)
    v = feeder - nest
    α = -atan(v[2], v[1])# - π/2
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
    # x.track.direction .+= α
    x.pellet.xy .= rot.(x.pellet.xy)
    x.originalnest = rot(x.originalnest) 
end

function rotate2!(x::Common, c)
    rot, α = get_rotation(c, x.feeder)
    x.nest = rot(x.nest)
    x.feeder = rot(x.feeder) 
    x.track.coords .= rot.(x.track.coords)
    # x.track.direction .+= α
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

