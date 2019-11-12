module DungAnalyse

using Revise
# Dates, VideoIO, Combinatorics, UUIDs, Observables
using DungBase, Serialization, Dates, JLSO, DataDeps, ProgressMeter, StaticArrays
using DelimitedFiles
# using FixedPointNumbers, ColorTypes
# using Images, CoordinateTransformations, LinearAlgebra, StaticArrays
# import VideoIO

# export build_calibrations

register(DataDep("coffeebeetle", "the coffee beetle database", "https://s3.eu-central-1.amazonaws.com/vision-group-file-sharing/Data%20backup%20and%20storage/Yakir/coffee%20beetles/database.zip", "557ec5027d34d2641db4f2cc61c993edd2ce2bee1530254d45d26cc41c5adf7a", post_fetch_method = unpack))


run(`s3fs -o uid=1000,gid=1000,allow_other binarybeetle /home/yakir/s3-drive`)
run(`mount`)
coffeesource = "s3-drive/coffee source/"

# include("ffmpeg.jl")
include("/home/yakir/dungProject/DungAnalyse/src/ffmpeg.jl")
include("/home/yakir/dungProject/DungAnalyse/src/calibrate.jl")
include("/home/yakir/dungProject/DungAnalyse/src/smooth.jl")
include("/home/yakir/dungProject/DungAnalyse/src/common_methods.jl")
include("/home/yakir/dungProject/DungAnalyse/src/quality_report.jl")
include("/home/yakir/dungProject/DungAnalyse/src/plotresults.jl")

# _formatcalibration(x) = replace(string(filenames(x), "_", Time(0) + start(x)), r"[^\w\d\s]" => "_")

#=function build_calibrations(coffeesource)
    sourcefolder = joinpath(coffeesource, "database")
    cs = deserialize(joinpath(sourcefolder, "calibration"))
    @showprogress 1 "saving calibration images…" for c in cs
        save_calibration_images(c, coffeesource)
    end
end


function build_calibrations(coffeesource, data::Dict{String,Experiment})
    @showprogress 1 "saving calibration images…" for (k,v) in data
        for r in v.runs, (k,p) in r.pois, (k,c) in p.calib
            build_calibration(coffeesource, k, c)
        end
    end
end=#


if !isfile(joinpath(datadep"coffeebeetle", "data.jlso"))
    include("/home/yakir/dungProject/DungAnalyse/src/load_from_csv.jl")
    loaddeomcsv()
end
data = JLSO.load(joinpath(datadep"coffeebeetle", "data.jlso"))
temporal2pixel = JLSO.load(datadep"coffeebeetle/temporal2pixel.jlso")["data"]

cs = Set{Calibration}()
for (_,v) in data, r in v.runs, (_,p) in r.data
    push!(cs, p.calib)
end
if !isfile(joinpath(coffeesource, "calibration errors.jlso"))
    nameerror = Dict{Calibration, NamedTuple{(:filename, :error),Tuple{String,Float64}}}()
    @showprogress 1 "Calibrating…" for c in cs
        nameerror[c] = build_calibration(coffeesource, hash(c), c)
    end
    JLSO.save(joinpath(coffeesource, "calibration errors.jlso"), nameerror)
end
nameerror = JLSO.load(joinpath(coffeesource, "calibration errors.jlso"))["data"]

function temp2pixel(k, p::POI{C, Temporal{V, I}}) where {C <: Calibration, V <: AbstractTimeLine, I <: Instantaneous}
    xyt = readdlm(joinpath(datadep"coffeebeetle/pixel", temporal2pixel[Pair(k, p)]))
    Instantaneous(xyt)
end
function temp2pixel(k, p::POI{C, Temporal{V, P}}) where {C <: Calibration, V <: AbstractTimeLine, P <: Prolonged}
    xyt = readdlm(joinpath(datadep"coffeebeetle/pixel", temporal2pixel[Pair(k, p)]))
    Prolonged(xyt)
end

pixeldata = Dict{String, Experiment}()
@showprogress 1 "loading pixel data…" for (experimentid, v) in data
    pixeldata[experimentid] = Experiment(Run[], v.description)
    for r in v.runs
        pois = Dict{Symbol, POI}()
        for (poitype, p) in r.data
            pois[poitype] = POI(nameerror[p.calib], temp2pixel(poitype, p))
        end
        push!(pixeldata[experimentid].runs, Run(pois, r.metadata))
    end
end
cmdata = Dict{String, Experiment}()
@showprogress 1 "Calibrating…" for (experimentid, v) in pixeldata
    cmdata[experimentid] = Experiment(Run[], v.description)
    for r in v.runs
        pois = Dict{Symbol, Any}()
        for (poitype, p) in r.data
            pois[poitype] = calibrate(p.calib.filename, p.data)
        end
        push!(cmdata[experimentid].runs, Run(pois, r.metadata))
    end
end
if !isfile(joinpath(coffeesource, "trackdata.jlso"))
    trackdata = Dict{String, Experiment}()
    @showprogress 1 "Tracking…" for (experimentid, v) in cmdata
        trackdata[experimentid] = Experiment([Run(Common(r), r.metadata) for r in v.runs], v.description)
        # break
    end
    JLSO.save(joinpath(coffeesource, "trackdata.jlso"), trackdata)
end
trackdata = JLSO.load(joinpath(coffeesource, "trackdata.jlso"))

fixpath(x) = replace(x, r"[\#\:\-]" => "_")

# experimentid = "nest#closed person#therese"
# v = cmdata[experimentid]
# trackdata = Dict{String, Experiment}()
# trackdata[experimentid] = Experiment([Run(Common(r), r.metadata) for r in v.runs], v.description)

@showprogress 1 "plotting…" for (experimentid, v) in data
    targetfiles = [start(r.data[:track].data.video) for r in v.runs]
    for (i, r) in enumerate(v.runs)
        path = fixpath(joinpath(coffeesource, "results", experimentid))
        mkpath(path)
        # plotquality(r.data, pixeldata[experimentid].runs[i].data, nameerror, cmdata[experimentid].runs[i].data, trackdata[experimentid].runs[i].data.track, r.metadata.comment, joinpath(path, fixpath(string("quality_", targetfiles[i], ".pdf"))))
        plotresult(trackdata[experimentid].runs[i].data, joinpath(path, fixpath(string("result_", targetfiles[i], ".pdf"))))
        # break
    end
    # break
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
