module DungAnalyse

# Dates, VideoIO, Combinatorics, UUIDs, Observables
using DungBase, Databula, Serialization, FileIO, Dates

export build_calibrations

include("videos.jl")
# include("/home/yakir/dungProject/DungAnalyse/src/videos.jl")

function fetchimages(c::Calibration{Temporal{V1,Prolonged},Temporal{V2,Instantaneous}}) where {V1 <: AbstractTimeLine, V2 <: AbstractTimeLine} 
    image = fetchimages(c.extrinsic)
    movie = fetchimages(c.intrinsic)
    (extrinsic = image, intrinsic = movie)
end

fetchimages(c::Calibration{Missing,Temporal{V,Instantaneous}}) where {V <: AbstractTimeLine} = (extrinsic = fetchimages(c.extrinsic), )

_formatcalibration(x) = replace(string(filenames(x), "_", Time(0) + start(x)), r"[^\w\d\s]" => "_")

function save_calibration_images(c::Calibration)
    path = joinpath(Databula.coffeesource, "calibration_images", _formatcalibration(c))
    mkpath(path)
    media = fetchimages(c)
    _save(path, media)
end

_save(path, media::NamedTuple{(:extrinsic)}) = FileIO.save(joinpath(path, "extrinsic.jpg"), media.extrinsic.image)

function _save(path, media::NamedTuple{(:extrinsic, :intrinsic)})
    extrinsic, intrinsic = media
    FileIO.save(joinpath(path, "extrinsic.jpg"), extrinsic.image)
    for (i, img) in enumerate(intrinsic.images)
        FileIO.save(joinpath(path, "$i.jpg"), img)
    end
end

function build_calibrations()
    cs = deserialize(joinpath(Databula.sourcefolder, "calibration"))
    for c in cs
        calibration = Databula._formatcalibration(c)
        if isfile(joinpath(Databula.coffeesource, first(filenames(c.extrinsic.video))))
            @info "saving calibration…" calibration
            save_calibration_images(c)
        else
            @warn "calibration is missing its video files" calibration
        end
    end
end




end # module

