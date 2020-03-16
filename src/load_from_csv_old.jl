using JuliaDB, UUIDs, CSV, Tables
import IntervalSets: width, (..), AbstractInterval, leftendpoint
function DungBase.AbstractTimeLine(x)
    files = Vector{VideoFile}(undef, length(x))
    for i in rows(x)
        files[i.index] = VideoFile(i.file_name, i.date_time, Millisecond(Nanosecond(i.duration)))
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
    tmp = select(table(x), Not(:date, :comment, :POI, :type))
    setup = Dict(k => v for (k, v) in pairs(tmp[1]) if !isempty(v))
    _x = x[1]
    date = _x.date
    comment = ismissing(_x.comment) ? "" : _x.comment
    metadata = Metadata(setup, comment, date)
    Run(pois, metadata)
end



function loaddeomcsv()

    video = loadtable(datadep"coffeebeetle/video.csv", indexcols = :video)
    videofile = loadtable(datadep"coffeebeetle/videofile.csv", indexcols = :file_name)
    x = join(video, videofile, rkey = :video)
    timeline = groupby(AbstractTimeLine,  x)
    interval = dropmissing(loadtable(datadep"coffeebeetle/interval.csv", indexcols = :interval), :start)
    x = join(interval, timeline, lkey = :video)
    temporal = dropmissing(groupby(Temporal, x, :interval), :Temporal)

    board = loadtable(datadep"coffeebeetle/board.csv", indexcols = :designation)
    calibration = loadtable(datadep"coffeebeetle/calibration.csv", indexcols = :calibration)
    x = join(calibration, board, lkey = :board, rkey = :designation)
    x = join(x, temporal, rkey = :interval, lkey = :extrinsic)
    x = select(x, Not(:extrinsic))
    x = JuliaDB.rename(x, :Temporal => :extrinsic)
    x = join(x, temporal, rkey = :interval, lkey = :intrinsic, how = :left)
    x = select(x, Not(:intrinsic))
    x = JuliaDB.rename(x, :Temporal => :intrinsic)
    calibration = groupby(Calibration, x, :calibration)

    poi = filter(!isempty, loadtable(datadep"coffeebeetle/poi.csv", indexcols = :poi), select = :calibration)
    coord = first.(splitext.(readdir(datadep"coffeebeetle/pixel")))
    poi = filter(in(coord), poi, select = :interval)
    x = join(poi, temporal, lkey = :interval)
    x = join(x, calibration, lkey = :calibration)
    x = select(x, Not(:calibration))
    x = JuliaDB.transform(x, :POI => POI.(x))


    temporal2pixel = Dict(Pair(Symbol(i.type), i.POI) => joinpath(datadep"coffeebeetle/pixel", string(i.interval, ".csv")) for i in x)

    JLSO.save(joinpath(datadep"coffeebeetle", "temporal2pixel.jlso"), temporal2pixel)
    poi = select(x, Not(:Temporal, :Calibration, :poi, :interval))

    runs = loadtable(datadep"coffeebeetle/run.csv", indexcols = :run)
    x = JuliaDB.transform(runs, :date => :date => Date)
    x = join(x, poi, rkey = :run)
    experiment = loadtable(datadep"coffeebeetle/experiment.csv", indexcols = :experiment)
    x = join(x, experiment, lkey = :experiment)
    data = groupby(x, :experiment) do xx
        runs = groupby(Run, select(table(xx), Not(:experiment_folder, :experiment_description)), :run)
        (Experiment = Experiment(select(runs, :Run), xx[1].experiment_description), name = xx[1].experiment_folder)
    end
    data = Dict(i.name => i.Experiment for i in data)

    JLSO.save(joinpath(datadep"coffeebeetle", "data.jlso"), data)
end

