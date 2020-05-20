module DungAnalyse

using DungBase, ProgressMeter, DelimitedFiles
# import Base.Threads: @spawn, @threads

export main, homing, searching, searchcenter, turningpoint



include("load_from_csv.jl")
include("ffmpeg.jl")
include("calibrate.jl")
include("common.jl")

function temp2pixel(coffeesource, temporal2pixel, k, p::POI{C, Temporal{V, I}}) where {C <: Calibration, V <: AbstractTimeLine, I <: Instantaneous}
    xyt = readdlm(joinpath(coffeesource, "pixel", temporal2pixel[Pair(k, p)]))
    Instantaneous(xyt)
end
function temp2pixel(coffeesource, temporal2pixel, k, p::POI{C, Temporal{V, P}}) where {C <: Calibration, V <: AbstractTimeLine, P <: Prolonged}
    xyt = readdlm(joinpath(coffeesource, "pixel", temporal2pixel[Pair(k, p)]))
    Prolonged(xyt)
end

build_calibrations(coffeesource, temporal2pixel, data) = Dict(c => build_calibration(coffeesource, hash(c), c) for c in unique(p.calib for (_,v) in data for r in v.runs for (_,p) in r.data))
# function build_calibrations(coffeesource, temporal2pixel, data)
#     cs = unique(p.calib for (_,v) in data for r in v.runs for (_,p) in r.data)
#     Dict(c => build_calibration(coffeesource, hash(c), c) for c in unique(p.calib for (_,v) in data for r in v.runs for (_,p) in r.data))
# end

raw2cm(data, nameerror, coffeesource, temporal2pixel) = Dict(experimentid => Experiment([Run(Common(Run(Dict(poitype => calibrate(nameerror[p.calib].filename, temp2pixel(coffeesource, temporal2pixel, poitype, p)) for (poitype, p) in r.data), r.metadata)), r.metadata) for r in v.runs], v.description) for (experimentid, v) in data)
# function raw2cm(data, nameerror, coffeesource, temporal2pixel)
#     n = 0
#     for v in values(data)
#         for r in v.runs
#             for _ in r.data
#                 n += 1
#             end
#         end
#     end
#     ph = Progress(n)
#     trackdata = Dict{String, Experiment}()
#     for (k, v) in data
#         runs = Vector{Run}(undef, length(v.runs))
#         for (i, r) in enumerate(v.runs)
#             pois = Dict{Symbol, Any}()
#             for (poitype, p) in r.data
#                 pois[poitype] = calibrate(nameerror[p.calib].filename, temp2pixel(coffeesource, temporal2pixel, poitype, p))
#                 next!(ph)
#             end
#             runs[i] = Run(Common(Run(pois, r.metadata)), r.metadata)
#         end
#         trackdata[k] = Experiment(runs, v.description)
#     end
#     return trackdata
# end

function main(coffeesource)
    temporal2pixel, data = loaddeomcsv(coffeesource)
    nameerror = build_calibrations(coffeesource, temporal2pixel, data)
    raw2cm(data, nameerror, coffeesource, temporal2pixel)
end

end # module

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
