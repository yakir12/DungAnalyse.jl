using MATLAB

calibrate(file, xyt) = last(splitext(file)) == ".csv" ? calibrate_csv(file, xyt) : calibrate_mat(file, xyt)

function calibrate_csv(csvfile, xyt::P) where {P <: AbstractPeriod}
    n = size(xyt.data,1)
    xy1 = [xyt.data[:,1:2] ones(n)]
    tform = readdlm(csvfile, ',', Float64)
    xy2 = xy1*tform
    xy3 = xy2[:,1:2]./xy2[:,3]
    P([xy3 xyt.data[:,3]])
end

function spawnmatlab(targetname, check, intrinsic, extrinsic)
    mat"""
    warning('off','all')
    [imagePoints, boardSize, imagesUsed] = detectCheckerboardPoints($intrinsic);
    $kept = 1:length($intrinsic);
    $kept = $kept(imagesUsed);
    extrinsicI = imread($extrinsic);
    sz = size(extrinsicI);
    worldPoints = generateCheckerboardPoints(boardSize, $check);
    %%
    params = estimateCameraParameters(imagePoints, worldPoints, 'ImageSize', sz, 'EstimateSkew', true, 'NumRadialDistortionCoefficients', 3, 'EstimateTangentialDistortion', true, 'WorldUnits', 'cm');
    n = size(imagePoints, 3);
    errors = zeros(n,1);
    for i = 1:n
        [R,t] = extrinsics(imagePoints(:,:,i), worldPoints, params);
        newWorldPoints = pointsToWorld(params, R, t, imagePoints(:,:,i));
        errors(i) = mean(vecnorm(worldPoints - newWorldPoints, 1, 2));
    end
    kill = errors > 1;
    while any(kill)
        imagePoints(:,:,kill) = [];    
        $kept(kill) = [];
        params = estimateCameraParameters(imagePoints, worldPoints, 'ImageSize', sz, 'EstimateSkew', true, 'NumRadialDistortionCoefficients', 3, 'EstimateTangentialDistortion', true, 'WorldUnits', 'cm');
        n = size(imagePoints, 3);
        errors = zeros(n,1);
        for i = 1:n
            [R,t] = extrinsics(imagePoints(:,:,i), worldPoints, params);
            newWorldPoints = pointsToWorld(params, R, t, imagePoints(:,:,i));
            errors(i) = mean(vecnorm(worldPoints - newWorldPoints, 1, 2));
        end
        kill = errors > 1;
    end
    $mean_error = mean(errors);
    %%
    MinCornerMetric = 0.15;
    xy = detectCheckerboardPoints(extrinsicI, 'MinCornerMetric', MinCornerMetric);
    MinCornerMetric = 0.;
    while size(xy,1) ~= size(worldPoints, 1)
        MinCornerMetric = MinCornerMetric + 0.05;
        xy = detectCheckerboardPoints(extrinsicI, 'MinCornerMetric', MinCornerMetric);
    end
    [R,t] = extrinsics(xy, worldPoints, params);
    save($targetname, 'params', 'R', 't')
    """
    kill = setdiff(1:length(intrinsic), kept)
    for i in kill
        rm(intrinsic[i])
    end
    mean_error
end

function spawnmatlab(targetname, check, extrinsic)
    mat"""
    warning('off','all')
    [imagePoints, boardSize] = detectCheckerboardPoints($extrinsic);
    worldPoints = generateCheckerboardPoints(boardSize, $check);
    tform_ = fitgeotrans(imagePoints, worldPoints, 'projective');
    $tform = tform_.T;
    %%
    [x, y] =  transformPointsForward(tform_, imagePoints(:,1), imagePoints(:,2));
    $mean_error = mean(vecnorm(worldPoints - [x, y], 2, 2))
    """
    writedlm(targetname, tform, ',')
    mean_error
end


function calibrate_mat(matfile, xyt::P) where {P <: AbstractPeriod}
    xy = xyt.data[:,1:2]
    mat"""
    a = load($matfile);
    $xy = pointsToWorld(a.params, a.R, a.t, $xy);
    """
    P([xy xyt.data[:,3]])
end

function build_calibration(coffeesource, calibId, c::Calibration{Temporal{V1, P}, Temporal{V2, I}}) where {V1 <: AbstractTimeLine, V2 <: AbstractTimeLine, P <: Prolonged, I <: Instantaneous} # moving
    path = joinpath(coffeesource, "calibration_images", string(calibId))
    mkpath(path)
    extract(joinpath(path, "extrinsic.png"), c.extrinsic, coffeesource)
    extract(path, c.intrinsic, coffeesource)
    intrinsic = [joinpath(path, f) for f in readdir(path) if f ≠ "extrinsic.png"]
    extrinsic = joinpath(path, "extrinsic.png")
    mkpath(joinpath(coffeesource, "autocalib"))
    targetname = joinpath(coffeesource, "autocalib", "$calibId.mat")
    ϵ = spawnmatlab(targetname, c.board.checker_width_cm, intrinsic, extrinsic)
    (filename = targetname, error = ϵ)
end

function build_calibration(coffeesource, calibId, c::Calibration{Missing, Temporal{V2, I}}) where {V1 <: AbstractTimeLine, V2 <: AbstractTimeLine, I <: Instantaneous}
    path = joinpath(coffeesource, "calibration_images", string(calibId))
    mkpath(path)
    extract(joinpath(path, "extrinsic.png"), c.extrinsic, coffeesource)
    extrinsic = joinpath(path, "extrinsic.png")
    mkpath(joinpath(coffeesource, "autocalib"))
    targetname = joinpath(coffeesource, "autocalib", "$calibId.csv")
    ϵ = spawnmatlab(targetname, c.board.checker_width_cm, extrinsic)
    (filename = targetname, error = ϵ)
end
