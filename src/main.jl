using Revise
using DungBase, UUIDs
import DungBase:AbstractTimeLine, Temporal, Board, Calibration, Run, Experiment
dbpath = "/home/yakir/dungProject/database"
cofeesource = "/home/yakir/mnt/coffee source"
using DataDeps, JuliaDB, Dates
register(DataDep("coffeebeetle2", "the coffee beetle database", "https://s3.eu-central-1.amazonaws.com/vision-group-file-sharing/Data%20backup%20and%20storage/Yakir/coffee%20beetles/database.zip", "557ec5027d34d2641db4f2cc61c993edd2ce2bee1530254d45d26cc41c5adf7a", post_fetch_method = unpack))
video = loadtable(datadep"coffeebeetle2/video.csv", indexcols = :video)
videofile = loadtable(datadep"coffeebeetle2/videofile.csv", indexcols = :file_name)
x = join(video, videofile, rkey = :video)
function AbstractTimeLine(x)
    n = length(x)
    if n == 1
        y = x[]
        comment = ismissing(y.comment) ? "" : y.comment
        WholeVideo(VideoFile(y.file_name, y.date_time, Nanosecond(y.duration)), comment)
    else
        files = Vector{VideoFile}(undef, length(x))
        for i in rows(x)
            files[i.index] = VideoFile(i.file_name, i.date_time, Nanosecond(i.duration))
        end
        y = x[1]
        comment = ismissing(y.comment) ? "" : y.comment
        FragmentedVideo(files, comment)
    end
end
timeline = groupby(AbstractTimeLine,  x)
interval = dropmissing(loadtable(datadep"coffeebeetle2/interval.csv", indexcols = :interval), :start)
x = join(interval, timeline, lkey = :video)
function Temporal(x)
    video = x.AbstractTimeLine
    time = AbstractPeriod(Nanosecond(x.start), x.stop)
    Temporal(video, time, ismissing(x.comment) ? "" : x.comment)
end
temporal = Dict(i.interval => Temporal(i) for i in x)

board = loadtable(datadep"coffeebeetle2/board.csv", indexcols = :designation)
calibration = loadtable(datadep"coffeebeetle2/calibration.csv", indexcols = :calibration)
x = join(calibration, board, lkey = :board)
function Calibration(x)
    intrinsic = get(temporal, x.intrinsic, missing)
    extrinsic = get(temporal, x.extrinsic, missing)
    board = Board(x.board, x.checker_width_cm, (x.checker_per_width, x.checker_per_height), x.board_description)
    comment = ismissing(x.comment) ? "" : x.comment
    Calibration(UUID(x.calibration), intrinsic, extrinsic, board, comment)
end
calibration = Dict(i.calibration => Calibration(i) for i in x)

connector = filter(!isempty, loadtable(datadep"coffeebeetle2/poi.csv", indexcols = :poi), select = :calibration)
using CSV, Tables
x = CSV.File(datadep"coffeebeetle2/run.csv", types = Dict(:date => Date)) |> rowtable
fname = setdiff(keys(x[1]), (:run, :date, :experiment, :comment))
x = map(x) do i
    (run = i.run, date = i.date, experiment = i.experiment, comment = i.comment, factors = Dict(s => getfield(i, s) for s in fname))
end
x = table(x, pkey = :run)
experiment = loadtable(datadep"coffeebeetle2/experiment.csv", indexcols = :experiment)
x = join(x, experiment, lkey = :experiment)
x = join(connector, x, lkey = :run, rkey = :run)
function Run(x)
    pois = Dict(Symbol(i.type) => POI(UUID(i.poi), calibration[i.calibration], temporal[i.interval]) for i in x)
    setup = x[1].factors
    date = x[1].date
    comment = ismissing(x[1].comment) ? "" : x[1].comment
    Run(pois, setup, date, comment)
end
function Experiment(x)
    runs = select(groupby(Run, table(x), :run), :Run)
    Experiment(runs, x[1].experiment_description)
end
t = groupby(Experiment, x, :experiment)

data = Dict(i.experiment => i.Experiment for i in t)


using Serialization
serialize(joinpath(datadep"coffeebeetle2", "data"), data)

using Revise
using Serialization
using DungBase, Dates, UUIDs
using DataDeps
register(DataDep("coffeebeetle2", "the coffee beetle database", "https://s3.eu-central-1.amazonaws.com/vision-group-file-sharing/Data%20backup%20and%20storage/Yakir/coffee%20beetles/database.zip", "557ec5027d34d2641db4f2cc61c993edd2ce2bee1530254d45d26cc41c5adf7a", post_fetch_method = unpack))
data = deserialize(joinpath(datadep"coffeebeetle2", "data"))

dbpath = "/home/yakir/dungProject/database"
for (k,v) in data, (i, run) in enumerate(v.runs)
    path = joinpath(dbpath, "experiments", k, string(i))
    mkpath(path)
end


t = data["nest#closed person#therese"].runs[1].pois[:nest].calib.intrinsic
imgs, sar = DungBase.fetchimages(t)

using Images, CoordinateTransformations, StaticArrays

tfm = LinearMap(SDiagonal(SVector(sar, 1)))
img = imgs[1]
imgw = warp(img, tfm);
imshow(imgw)



pixel = Dict{
for file in readdir(datadep"coffeebeetle/pixel")




ENV["FFREPORT"] = "8"
using VideoIO

file = download("https://s3.eu-central-1.amazonaws.com/vision-group-file-sharing/Fun%20Stuff/a.MTS")

file = "/home/yakir/videos/scallop/Swimming Scallops-KQHg6M7-Du0.mp4"
f = openvideo(file)
seek(f, 3.0)

read(f)

file = "/home/yakir/Brooklyn Nine-Nine Season 5/Brooklyn Nine-Nine S05E01.mkv"
f = openvideo(file)
sar = f.aspect_ratio
if sar ≠ 0 && sar ≠ 1
    <deal with a freaky SAR>
end

playvideo(f, pixelaspectratio=1.0)


While the Data Aspect Ratio (DAR) or Pixel Aspect Ration (PAR) can be safely assumed to be equal to one (in modern times this means the shape of the pixels is square), in some cases this aspect ratio may be smaller or larger than one. In such cases, an image will look unnaturally wide/tall. To retrieve the reported aspect ratio form a file use:
``` 
f = openvideo(file)
sar = f.aspect_ratio
```
Note that not all videos store a correct apsect ratio. In such umbigous cases, `ffmpeg` will report a ratio of `0//1`. To help identify a truly ≠1 ratio use:
``` 
if sar ≠ 1 && sar ≠ 0
    <...>
end
```
