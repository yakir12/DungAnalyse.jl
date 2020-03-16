module DungAnalyse

using DungBase, Serialization, Dates, JLSO, DataDeps, ProgressMeter, StaticArrays, DelimitedFiles
import Base.Threads: @spawn, @threads

export main

include("ffmpeg.jl")
include("calibrate.jl")
include("smooth.jl")
include("common_methods.jl")
include("quality_report.jl")
include("plotresults.jl")
include("load_from_csv.jl")

function temp2pixel(coffeesource, temporal2pixel, k, p::POI{C, Temporal{V, I}}) where {C <: Calibration, V <: AbstractTimeLine, I <: Instantaneous}
    xyt = readdlm(joinpath(coffeesource, "pixel", temporal2pixel[Pair(k, p)]))
    Instantaneous(xyt)
end

function temp2pixel(coffeesource, temporal2pixel, k, p::POI{C, Temporal{V, P}}) where {C <: Calibration, V <: AbstractTimeLine, P <: Prolonged}
    xyt = readdlm(joinpath(coffeesource, "pixel", temporal2pixel[Pair(k, p)]))
    Prolonged(xyt)
end

function main2(data, nameerror, coffeesource, temporal2pixel)
    n = 0
    for v in values(data)
        for r in v.runs
            for _ in r.data
                n += 1
            end
        end
    end
    ph = Progress(n)
    trackdata = Dict{String, Experiment}()
    for (k, v) in data
        runs = Vector{Run}(undef, length(v.runs))
        for (i, r) in enumerate(v.runs)
            pois = Dict{Symbol, Any}()
            for (poitype, p) in r.data
                pois[poitype] = calibrate(nameerror[p.calib].filename, temp2pixel(coffeesource, temporal2pixel, poitype, p))
                next!(ph)
            end
            runs[i] = Run(Common(Run(pois, r.metadata)), r.metadata)
        end
        trackdata[k] = Experiment(runs, v.description)
    end
    return trackdata
end

function main(coffeesource)
    temporal2pixel, data = loaddeomcsv(coffeesource)
    cs = unique(p.calib for (_,v) in data for r in v.runs for (_,p) in r.data)
    @info "started building calibrations"
    nameerror = Dict(c => build_calibration(coffeesource, hash(c), c) for c in unique(p.calib for (_,v) in data for r in v.runs for (_,p) in r.data))
    @info "finished building calibrations"

    # nameerror = Dict()
    # @threads for c in cs
    #     nameerror[c] = build_calibration(coffeesource, hash(c), c) 
    # end

    # nameerror = Dict(c => build_calibration(coffeesource, hash(c), c) for c in unique(p.calib for (_,v) in data for r in v.runs for (_,p) in r.data))
    #=trackdata = Dict()
    for (experimentid, v) in data
    n = length(v.runs)
    runs = Vector{Run}(undef, n)
    # for i in 1:n
    @sync for i in 1:n
    @spawn begin
    r = v.runs[i]
    n = length(r.data)
    poitypes = collect(keys(r.data))
    pois = Vector{Any}(undef, n)
    for j in 1:n
    @spawn begin
    poitype = poitypes[j]
    p = r.data[poitype]
    pois[j] = calibrate(nameerror[p.calib].filename, temp2pixel(coffeesource, temporal2pixel, poitype, p))
    end
    end
    runs[i] = Run(Common(Run(Dict(poitype => poi for (poitype, poi) in zip(keys(r.data), pois)), r.metadata)), r.metadata)
    end
    end
    trackdata[experimentid] = Experiment(runs, v.description)
    end=#

    # trackdata = Dict(experimentid => Experiment([Run(Common(Run(Dict(poitype => calibrate(nameerror[p.calib].filename, temp2pixel(coffeesource, temporal2pixel, poitype, p)) for (poitype, p) in r.data), r.metadata)), r.metadata) for r in v.runs], v.description) for (experimentid, v) in data)


    #=vs = collect(values(data))
    n = length(vs)
    ys = Vector{Experiment}(undef, n)
    @threads for i in 1:n
    v = vs[i]
    ys[i] = Experiment([Run(Common(Run(Dict(poitype => calibrate(nameerror[p.calib].filename, temp2pixel(coffeesource, temporal2pixel, poitype, p)) for (poitype, p) in r.data), r.metadata)), r.metadata) for r in v.runs], v.description)
    end
    trackdata = Dict(zip(keys(data), ys))=#

    n = 0
    for v in values(data)
        for r in v.runs
            for _ in r.data
                n += 1
            end
        end
    end
    ph = Progress(n)
    trackdata = Dict{String, Experiment}()
    for (k, v) in data
        runs = Vector{Run}(undef, length(v.runs))
        for (i, r) in enumerate(v.runs)
            pois = Dict{Symbol, Any}()
            for (poitype, p) in r.data
                pois[poitype] = calibrate(nameerror[p.calib].filename, temp2pixel(coffeesource, temporal2pixel, poitype, p))
                next!(ph)
            end
            runs[i] = Run(Common(Run(pois, r.metadata)), r.metadata)
        end
        trackdata[k] = Experiment(runs, v.description)
    end
    #=@sync for (k, v) in data
    @spawn begin
    runs = Vector{Run}(undef, length(v.runs))
    for (i, r) in enumerate(v.runs)
    @spawn begin
    pois = Dict{Symbol, Any}()
    @sync for (poitype, p) in r.data
    @spawn pois[poitype] = calibrate(nameerror[p.calib].filename, temp2pixel(coffeesource, temporal2pixel, poitype, p))
    next!(ph)
    end
    runs[i] = Run(Common(Run(pois, r.metadata)), r.metadata)
    end
    end
    trackdata[k] = Experiment(runs, v.description)
    end
    end=#

    return trackdata
end

end # module

# experimentid = "transfer#far person#therese"
# v = data[experimentid]

# TODO
# change terminology to nest and imaginary nest
# make sure all the terms (like direction etc) are consistent
# define where the binary stops are for the pipeline
# consider how the code works on the experiment[run] versus just run[]
# check all runs
# filter away bad ones
# adjust turning point algorithm
# consider saving the calibration images in a tmp folder instead
# have a thorough walk through the code to fine tune stuff
# consider that calibrations might be better connected to the videos than to the temporals...
# create the regression plot for marie
