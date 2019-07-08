module DungAnalyse

# Dates, VideoIO, Combinatorics, UUIDs, Observables
using DungBase, Databula, Serialization, FileIO, Dates
# using FixedPointNumbers, ColorTypes
using Images, CoordinateTransformations, LinearAlgebra
import VideoIO


export build_calibrations

include("videos.jl")
# include("/home/yakir/dungProject/DungAnalyse/src/videos.jl")

temporal2image(c::Calibration) = Calibration(c, (intrinsic = fetchimages(c.intrinsic), extrinsic = fetchimages(c.extrinsic)))

_formatcalibration(x) = replace(string(filenames(x), "_", Time(0) + start(x)), r"[^\w\d\s]" => "_")

function save_calibration_images(c::Calibration)
    path = joinpath(Databula.coffeesource, "calibration_images", _formatcalibration(c))
    mkpath(path)
    cc = temporal2image(c)
    _save(path, cc.extrinsic)
    _save(path, cc.intrinsic)
end

_save(path, _::Missing) = nothing
_save(path, extrinsic::Snapshot{PAR1}) = FileIO.save(joinpath(path, "extrinsic.jpg"), extrinsic.img)
function _save(path, extrinsic::Snapshot{PAR})
    tfm = LinearMap(Diagonal(SVector(1, par(extrinsic))))
    imgw = warp(extrinsic.img, tfm)
    FileIO.save(joinpath(path, "extrinsic.jpg"), imgw)
end
function _save(path, intrinsic::TimeLapse{PAR1}, counter)
    for (i, frame) in enumerate(intrinsic.imgs)
        name = i + counter
        FileIO.save(joinpath(path, "$j.jpg"), img)
    end
end
function _save(path, intrinsic::TimeLapse{PAR}, counter)
    tfm = LinearMap(Diagonal(SVector(1, par(intrinsic))))
    for (i, frame) in enumerate(intrinsic.imgs)
        imgw = warp(frame, tfm)
        name = i + counter
        FileIO.save(joinpath(path, "$j.jpg"), imgw)
    end
end
_save(path, intrinsic::TimeLapse) = _save(path, intrinsic, 0)

function build_calibrations()
    cs = deserialize(joinpath(Databula.sourcefolder, "calibration"))
    for c in cs
        calibration = Databula._formatcalibration(c)
        @info "saving calibration…" calibration
        save_calibration_images(c)
    end
end




end # module

