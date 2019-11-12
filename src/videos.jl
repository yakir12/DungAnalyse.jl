abstract type AbstractPAR end

struct PAR <: AbstractPAR
    value::Rational{UInt32}
end

struct PAR1 <: AbstractPAR
end

AbstractPAR(x) = isone(x) ? PAR1() : PAR(x)

par(x::PAR) = x.value
par(_::PAR1) = 1//1

const Image = Matrix{RGB{N0f8}}#PermutedDimsArray{RGB{Normed{UInt8,8}},2,(2, 1),(2, 1),Array{RGB{Normed{UInt8,8}},2}} #{RGB{Normed{UInt8,8}}}

abstract type AbstractPhotage end

struct Snapshot{P <: AbstractPAR} <: AbstractPhotage
    img::Image
    par::P
end

struct TimeLapse{P <: AbstractPAR} <: AbstractPhotage
    imgs::Vector{Image}
    par::P
end

par(x::AbstractPhotage) = par(x.par)


const STEP = Millisecond(60)

timestamps(t::Temporal{WholeVideo, Instantaneous}) = (t.video.file.name, start(t.time))

function timestamps(t::Temporal{FragmentedVideo, Instantaneous})
    t = start(t.time)
    for vf in files(t.video)
        d = duration(vf)
        if t ≤ d
            return (vf.name, t)
        end
        t -= d
    end
end

timestamps(t::Temporal{WholeVideo, Prolonged}) = (t.video.file.name, start(t.time):STEP:stop(t.time))

function timestamps(t::Temporal{FragmentedVideo, Prolonged})
    ranges = Dict{String, StepRange{Millisecond,Millisecond}}()
    t1 = start(t.time)
    t2 = stop(t.time)
    files = Iterators.Stateful(t.video.files)
    for vf in files
        if t1 ≤ vf.duration
            if t2 ≤ vf.duration
                ranges[vf.name] = t1:STEP:t2
                return ranges
            else
                ranges[vf.name] = t1:STEP:vf.duration
                t2 -= vf.duration
                for _vf in files
                    if t2 ≤ _vf.duration
                        ranges[_vf.name] = Millisecond(0):STEP:t2
                        return ranges
                    end
                    ranges[_vf.name] = Millisecond(0):STEP:_vf.duration
                    t2 -= _vf.duration
                end
            end
        end
        t1 -= vf.duration
        t2 -= vf.duration
    end
end

ms2s(t::Millisecond) = t/Millisecond(1000)

function seekread(f, s::Float64)
    seek(f, s)
    full = read(f)
    full[1:2:end, :]
end

fetchimages(_::Missing) = missing

function fetchimages(t::Temporal{V, Instantaneous}) where V
    file, time = timestamps(t)
    f = VideoIO.openvideo(joinpath(Databula.coffeesource, file))
    img = seekread(f, ms2s(time))
    sar = 2VideoIO.aspect_ratio(f)
    Snapshot(img, AbstractPAR(sar))
end

function fetchimages(t::Temporal{WholeVideo, Prolonged})
    file, times = timestamps(t)
    f = VideoIO.openvideo(joinpath(Databula.coffeesource, file))
    imgs = [seekread(f, ms2s(t)) for t in times]
    sar = 2VideoIO.aspect_ratio(f)
    TimeLapse(imgs, AbstractPAR(sar))
end

function fetchimages(t::Temporal{FragmentedVideo, Prolonged})
    ft = timestamps(t)
    imgs = Vector{TimeLapse}(undef, length(ft))
    for (i, (file, times)) in enumerate(ft)
        f = VideoIO.openvideo(joinpath(Databula.coffeesource, file))
        _imgs = [seekread(f, ms2s(t)) for t in times]
        sar = 2VideoIO.aspect_ratio(f)
        imgs[i] = TimeLapse(_imgs, AbstractPAR(sar))
    end
    imgs
end

