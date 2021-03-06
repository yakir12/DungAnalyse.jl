using CSV, JuliaDB, DungBase, Dates, UUIDs, Tables, TableOperations
import IntervalSets: width, (..), AbstractInterval, leftendpoint
import DataFrames: DataFrame
import Base.Threads: @spawn
# format2millisecond(_::Missing) = missing
# function format2millisecond(x) 
#     m = match(r"^(\d*)\smilliseconds?$", x)
#     isnothing(m) && return missing
#     Millisecond(parse(Int, first(m.captures)))
# end
tons(_::Missing) = missing
tons(x) = Nanosecond(x)
function DungBase.AbstractTimeLine(x)
    files = Vector{VideoFile}(undef, length(x))
    for i in rows(x)
        files[i.index] = VideoFile(i.file_name, i.date_time, i.duration)
    end
    y = x[1]
    comment = ismissing(y.comment) ? "" : y.comment
    AbstractTimeLine(files, comment)
end
DungBase.AbstractPeriod(x, y::Missing) = AbstractPeriod(x)
function DungBase.Temporal(xs)
    x = xs[]
    video = x.AbstractTimeLine
    p1 = Millisecond(Nanosecond(x.start))
    p = ismissing(x.stop) ? p1 : p1..Millisecond(Nanosecond(x.stop))
    time = AbstractPeriod(p)
    try
        Temporal(video, time, ismissing(x.comment) ? "" : x.comment)
    catch
        Temporal(video, Prolonged(), ismissing(x.comment) ? "the time is made up because it was missing" : x.comment*" the time is made up because it was missing") 
    end
end
function DungBase.Calibration(_x)
    x = _x[]
    board = Board(x.board, x.checker_width_cm, (x.checker_per_width, x.checker_per_height), x.board_description)
    comment = ismissing(x.comment) ? "" : x.comment
    Calibration(x.intrinsic, x.extrinsic, board, comment)
end
DungBase.POI(x) = POI(x.Calibration, x.Temporal)
function DungBase.Run(x)
    @assert allunique(x.type) "POI types are not unique: $(x.type)"
    pois = Dict(Symbol(i.type) => i.POI for i in x)
    tmp = select(table(x), Not(All(:date, :comment, :POI, :type)))
    # CSV.write("/home/yakir/coffeebeetlearticle/all/tmp.csv", tmp)
    setup = Dict(k => v for (k, v) in pairs(tmp[1]) if !ismissing(v))
    _x = x[1]
    date = _x.date
    comment = ismissing(_x.comment) ? "" : _x.comment
    metadata = Metadata(setup, comment, date)
    Run(pois, metadata)
end



function loaddeomcsv(source)

    t = CSV.File(joinpath(source, "video.csv")) |> TableOperations.transform(video = UUID)
    video = table(t, pkey = :video)
    t = CSV.File(joinpath(source, "videofile.csv")) |> TableOperations.transform(video = UUID, duration = tons)
    # t = CSV.File(joinpath(source, "videofile.csv")) |> TableOperations.transform(video = UUID, duration = format2millisecond)
    videofile = table(t, pkey = :file_name)
    x = join(video, videofile, rkey = :video)
    timeline = groupby(AbstractTimeLine,  x)
    t = CSV.File(joinpath(source, "interval.csv")) |> TableOperations.transform(interval = UUID, video = x -> ismissing(x) ? missing : UUID(x), start = tons, stop = tons)
    # t = CSV.File(joinpath(source, "interval.csv")) |> TableOperations.transform(interval = UUID, video = UUID, start = format2millisecond, stop = format2millisecond)
    interval = table(t, pkey = :interval)
    # interval = dropmissing(loadtable(joinpath(source, "interval.csv"), indexcols = :interval), :start)
    x = join(interval, timeline, lkey = :video)
    temporal = dropmissing(groupby(Temporal, x, :interval), :Temporal)

    board = loadtable(joinpath(source, "board.csv"), indexcols = :designation)
    t = CSV.File(joinpath(source, "calibration.csv")) |> TableOperations.transform(calibration = UUID, intrinsic = x -> ismissing(x) ? missing : UUID(x), extrinsic = UUID, board = String)
    calibration = table(t, pkey = :calibration)
    x = join(calibration, board, lkey = :board, rkey = :designation)
    x = join(x, temporal, rkey = :interval, lkey = :extrinsic)
    x = select(x, Not(:extrinsic))
    x = JuliaDB.rename(x, :Temporal => :extrinsic)
    x = join(x, temporal, rkey = :interval, lkey = :intrinsic, how = :left)
    x = select(x, Not(:intrinsic))
    x = JuliaDB.rename(x, :Temporal => :intrinsic)
    calibration = groupby(Calibration, x, :calibration)

    t = CSV.File(joinpath(source, "poi.csv")) |> TableOperations.transform(poi = UUID, run = UUID, calibration = x -> ismissing(x) ? missing : UUID(x), interval = x -> ismissing(x) ? missing : UUID(x))
    poi = table(t, pkey = :poi)
    coord = UUID.(first.(splitext.(readdir(joinpath(source, "pixel")))))
    poi = filter(in(coord), poi, select = :interval)
    x = join(poi, temporal, lkey = :interval)
    x = join(x, calibration, lkey = :calibration)
    x = select(x, Not(:calibration))
    x = JuliaDB.transform(x, :POI => POI.(x))


    temporal2pixel = Dict(Pair(Symbol(i.type), i.POI) => joinpath(joinpath(source, "pixel"), string(i.interval, ".csv")) for i in x)

    # JLSO.save(joinpath(source, "temporal2pixel.jlso"), "food" => "☕️🥓🍳", "cost" => 11.95, "time" => Time(9, 0))

    poi = select(x, Not(All(:Temporal, :Calibration, :poi, :interval)))
    t = CSV.File(joinpath(source, "run.csv")) |> TableOperations.transform(run = UUID)
    runs = table(t, pkey = :run)
    # x = JuliaDB.transform(runs, :date => :date => Date)
    x = join(runs, poi, rkey = :run)
    experiment = loadtable(joinpath(source, "experiment.csv"), indexcols = :experiment)
    x = join(x, experiment, lkey = :experiment)

    data = groupby(x, :experiment, usekey = true) do k, xx
        runs = groupby(Run, select(table(xx), Not(All(:experiment_folder, :experiment_description))), :run)
        (Experiment = Experiment(select(runs, :Run), xx[1].experiment_description), name = k.experiment)
        # (Experiment = Experiment(select(runs, :Run), xx[1].experiment_description), name = xx[1].experiment_folder)
    end

    data = Dict(i.name => i.Experiment for i in data)

    return temporal2pixel, data

    # JLSO.save(joinpath(datadep"coffeebeetle", "data.jlso"), data)
end



goodvideo(file) = first(file) ≠ '.' && occursin(r"mts|mp4|avi|mpg|mov|mkv"i, last(splitext(file)))

function joinsources(sources; prefix = "source_")
    source = mktempdir(; prefix = prefix, cleanup = false)
    pixel = joinpath(source, "pixel")
    mkdir(pixel)
    @sync for s in sources
        @spawn begin
            pp = joinpath(s, "pixel")
            for p in readdir(pp)
                @assert p ∉ readdir(pixel) "duplicate pixel files"
                # mv(joinpath(pp, p), joinpath(pixel, p))
                cp(joinpath(pp, p), joinpath(pixel, p))
            end
            # rm(pp)
        end
    end
    @sync for x in ("board", "calibration", "experiment", "interval", "poi", "video", "videofile")
        @spawn begin 

            open(joinpath(source, "$x.csv"), "w") do i
                open(joinpath(sources[1], "$x.csv")) do o
                    write(i, read(o))
                end
                for s in Iterators.drop(sources, 1)
                    open(joinpath(s, "$x.csv")) do o
                        readuntil(o, '\n')
                        write(i, read(o))
                    end
                end
            end

            # for s in sources
                # rm(joinpath(s, "$x.csv"))
            # end
        end
    end

    runs = vcat((DataFrame(CSV.File(joinpath(s, "run.csv"))) for s in sources)..., cols = :union)
    CSV.write(joinpath(source, "run.csv"), runs)

    @sync for s in sources
        @spawn begin
            for p in readdir(s)
                if goodvideo(p)
                    @assert p ∉ readdir(source) "duplicate video files"
                    cp(joinpath(s, p), joinpath(source, p))
                end
            end
        end
    end
    # for s in sources
    #     @assert isempty(readdir(s)) "some files remain?"
    #     rm(s)
    # end
    return source
end



