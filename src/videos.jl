using FixedPointNumbers, ColorTypes#, FileIO
import VideoIO

const STEP = Nanosecond(333333333)

timestamps(t::Temporal{WholeVideo, Instantaneous}) = (t.video.file.name, t.time.anchor)

function timestamps(t::Temporal{FragmentedVideo, Instantaneous})
    time = t.time.anchor
    for vf in t.video.files
        if time ≤ vf.duration
            return (vf.name, time)
        end
        time -= vf.duration
    end
end

timestamps(t::Temporal{WholeVideo, Prolonged}) = (t.video.file.name, t.time.anchor:STEP:stop(t.time))

function timestamps(t::Temporal{FragmentedVideo, Prolonged})
    ranges = Dict{String, StepRange{Nanosecond,Nanosecond}}()
    t1 = t.time.anchor
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
                        ranges[_vf.name] = Nanosecond(0):STEP:t2
                        return ranges
                    end
                    ranges[_vf.name] = Nanosecond(0):STEP:_vf.duration
                    t2 -= _vf.duration
                end
            end
        end
        t1 -= vf.duration
        t2 -= vf.duration
    end
end

# tosecond{T}(t::T) = t/convert(T, Dates.Second(1))
ns2s(t) = t/Nanosecond(1000000000)

function seekread(f, s)
    seek(f, s)
    read(f)
end


function fetchimages(t::Temporal{V, Instantaneous}) where V
    file, time = timestamps(t)
    f = VideoIO.openvideo(joinpath(Databula.coffeesource, file))
    img = seekread(f, ns2s(time))
    sar = VideoIO.aspect_ratio(f)
    (image = img, sar = sar)
end

function fetchimages(t::Temporal{WholeVideo, Prolonged})
    file, times = timestamps(t)
    f = VideoIO.openvideo(joinpath(Databula.coffeesource, file))
    imgs = [seekread(f, ns2s(t)) for t in times]
    #=imgs = Vector{Matrix{RGB{Normed{UInt8,8}}}}(undef, length(times))
    for (i, time) in enumerate(times)
        seek(f, ns2s(time))
        imgs[i] = read(f)
    end=#
    sar = VideoIO.aspect_ratio(f)
    (images = imgs, sar = sar)
end

function fetchimages(t::Temporal{FragmentedVideo, Prolonged})
    ft = timestamps(t)
    # imgs = Vector{Matrix{RGB{Normed{UInt8,8}}}}(undef, sum(length, values(ft)))
    imgs = []#Vector{Tuple{Vector{Matrix{RGB{Normed{UInt8,8}}}}, }(undef, length(ft))
    # i = 0
    for (i, (file, times)) in enumerate(ft)
        f = VideoIO.openvideo(joinpath(Databula.coffeesource, file))
        _imgs = [seekread(f, ns2s(t)) for t in times]
        sar = VideoIO.aspect_ratio(f)
        imgs[i] = (images = _imgs, sar = sar)
        #=for time in times
            # i += 1
            seek(f, ns2s(time))
            img = read(f)
            # push!(imgs, img)
            # FileIO.save("tmp/$i.jpg", img)
            imgs[i] = img
        end=#
    end
    # f = VideoIO.openvideo(joinpath(Databula.coffeesource, first(keys(ft))))
    # sar = VideoIO.aspect_ratio(f)
    imgs
end

