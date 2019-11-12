using FFMPEG 

tosecond(x::Hour) = Float64(Dates.value(Second(x)))
tosecond(x::Minute) = Float64(Dates.value(Second(x)))
tosecond(x::T) where {T<:TimePeriod} = x/convert(T, Second(1))

# extract(_, __::Missing, ___) = nothing

ffmpeg(start, sourcefile, targetfile) = ffmpeg_exe(` -y -nostats -loglevel 8 -ss $start -i $sourcefile -vf 'yadif=1,format=gray,scale=sar*iw:ih' -pix_fmt gray -vframes 1 $targetfile`)

extract(targetpathfile, t::Temporal{WholeVideo, I}, coffeesource) where {I <: Instantaneous} = ffmpeg(tosecond(start(t.time)), joinpath(coffeesource, t.video.file.name), targetpathfile) 

function extract(targetpathfile, t::Temporal{<:FragmentedVideo, I}, coffeesource) where {I <: Instantaneous}
    x = start(t.time)
    for vf in files(t.video)
        d = duration(vf)
        if x ≤ d
            ffmpeg(tosecond(x), joinpath(coffeesource, vf.name), targetpathfile)
            break
        end
        x -= d
    end
end

ffmpeg(start, duration, sourcefile, targetpathfile) = ffmpeg_exe(` -y -nostats -loglevel 8 -ss $start -i $sourcefile -t $duration -r 2 -vf 'yadif=1,format=gray,scale=sar*iw:ih' -pix_fmt gray $targetpathfile`)

getsourcefile(coffeesource, t) = joinpath(coffeesource, t)
function getsourcetarget(coffeesource, t, targetpath)
    sourcefile = getsourcefile(coffeesource, t)
    sourcefile, joinpath(targetpath, "img%03d.png")
end
extract(targetpath, t::Temporal{WholeVideo, P}, coffeesource) where {P <: Prolonged} = ffmpeg(tosecond(start(t.time)), tosecond(duration(t.time)), getsourcetarget(coffeesource, t.video.file.name, targetpath)...)

function extract(targetpath, t::Temporal{<:FragmentedVideo, P}, coffeesource) where {P <: Prolonged}
    t1 = start(t.time)
    t2 = stop(t.time)
    files = Iterators.Stateful(t.video.files)
    for vf in files
        d = duration(vf)
        if t1 ≤ d
            if t2 ≤ d
                ffmpeg(tosecond(t1), tosecond(t2 - t1), getsourcetarget(coffeesource, vf.name, targetpath)...)
                break
            else
                ffmpeg(tosecond(t1), tosecond(d), getsourcetarget(coffeesource, vf.name, targetpath)...)
                t2 -= d
                for _vf in files
                    _d = duration(_vf)
                    if t2 ≤ _d
                        ffmpeg(tosecond(Millisecond(0)), tosecond(t2), getsourcetarget(coffeesource, _vf.name, targetpath)...)
                        break
                    end
                    ffmpeg(tosecond(Millisecond(0)), tosecond(_d), getsourcetarget(coffeesource, _vf.name, targetpath)...)
                    t2 -= _d
                end
            end
        end
        t1 -= d
        t2 -= d
    end
end

