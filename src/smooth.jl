using LowLevelParticleFilters, LinearAlgebra, StaticArrays, Distributions, Random

#=M = 1000 # Number of smoothing trajectories, NOTE: if this is set higher, the result will be better at the expense of linear scaling of the computational cost.
N = 1000 # Number of particles in the particle filter
@inline pos(s) = s[SVector(1,2)]

dgσ = 1#0.1 # the deviation of the measurement noise distribution
dvσ = 1#1 # the deviation of the dynamics noise distribution
daσ = 0.7#1

const dg = MvNormal(zero(SVector{2, Float64}), dgσ)
const df = MvNormal(zero(SVector{4, Float64}), [0.01, 0.01, dvσ, daσ])

const noisevec = zeros(4)

@inline function dynamics(s,u,t,noise=false)
    # current states
    x, y, v, a = s
    # get noise
    if noise
        x_noise, y_noise, v_noise, a_noise = rand!(df, noisevec)
    else
        x_noise, y_noise, v_noise, a_noise = 0.,0.,0.,0.
    end
    # next states
    dy, dx = sincos(a)
    x += x_noise + dx*v 
    y += y_noise + dy*v 
    v⁺ = max(0.999v + v_noise, 0.0)
    a += a_noise
    SVector{4,Float64}(x, y, v⁺, a)
end
function measurement_likelihood(s,y,t)
    logpdf(dg, pos(s)-y) # A simple linear measurement model with normal additive noise
end
@inline measurement(s,t=1) = pos(s)
@inline measurement(s,t,noise) = measurement(s) + noise*rand(dg) # We observer the position coordinates with the measurement

function smoothed(xy)
    d0 = MvNormal(SVector(xy[1]..., norm(xy[2] - xy[1]), atan(reverse(xy[2] - xy[1])...)), ones(4))
    u = zeros(length(xy))
    pf = AuxiliaryParticleFilter(AdvancedParticleFilter(N, dynamics, measurement, measurement_likelihood, df, d0))
    x1,w,we,ll=forward_trajectory(pf,u,xy)
    xh = mean_trajectory(x1,we)
    sb, _ = smooth(pf, M, u, xy) # Sample smooting particles (b for backward-trajectory)
    s = smoothed_mean(sb)     # Calculate the mean of smoothing trajectories
    s[1:2, :], s[3, :], s[4, :]
end=#











M = 100 # Number of smoothing trajectories, NOTE: if this is set higher, the result will be better at the expense of linear scaling of the computational cost.
N = 1000 # Number of particles in the particle filter
@inline pos(s) = s[SVector(1,2)]

dgσ = 3#0.1 # the deviation of the measurement noise distribution
dvσ = 1#1 # the deviation of the dynamics noise distribution
daσ = 0.06 # 0.05 works really well

const dg = MvNormal(zero(SVector{2, Float64}), dgσ)
# const df = MvNormal(zero(SVector{4, Float64}), [0.01, 0.01, dvσ, daσ])
const switch_prob = 0.01
const df = LowLevelParticleFilters.TupleProduct((Normal.(0,[0.01, 0.01, dvσ, daσ])..., Binomial(1, switch_prob)))

const noisevec = zeros(5)

@inline function dynamics(s,u,t,noise=false)
    # current states
    x, y, v, a, m = s
    # get noise
    if noise
        x_noise, y_noise, v_noise, a_noise, _ = rand!(df, noisevec)
    else
        x_noise, y_noise, v_noise, a_noise = 0.,0.,0.,0.
    end
    # next states
    dy, dx = sincos(a)
    x += x_noise + dx*v 
    y += y_noise + dy*v 
    v⁺ = max(0.999v + v_noise, 0.0)
    m⁺ = m == 0 ? Int(rand() < switch_prob) : 1
    a += a_noise*(1 + 6m⁺)
    SVector{5,Float64}(x, y, v⁺, a, m⁺)
end
function measurement_likelihood(s,y,t)
    logpdf(dg, pos(s)-y) # A simple linear measurement model with normal additive noise
end
@inline measurement(s,t=1) = pos(s)
@inline measurement(s,t,noise) = measurement(s) + noise*rand(dg) # We observer the position coordinates with the measurement

function smoothed(xy)
    d0 = MvNormal(SVector(xy[1]..., norm(xy[2] - xy[1]), atan(reverse(xy[2] - xy[1])...), 0), Float64[1, 1, 1, 1, 0])
    u = zeros(length(xy))
    pf = AuxiliaryParticleFilter(AdvancedParticleFilter(N, dynamics, measurement, measurement_likelihood, df, d0))
    # x1,w,we,ll=forward_trajectory(pf,u,xy)
    # xh = mean_trajectory(x1,we)
    sb, _ = smooth(pf, M, u, xy) # Sample smooting particles (b for backward-trajectory)
    s = smoothed_mean(sb)     # Calculate the mean of smoothing trajectories
    s[1:2, :], s[3, :], s[4, :], s[5, :]
end

# 26 41
#=i = Common(x[5])
xy = i.track.xy
_xy, v, a, m = smoothed(xy)
xys = Point.(eachcol(_xy))
tp = findfirst(x -> x > 0.5, m)
sc = Scene(scale_plot = false, limits = FRect(-100, -100, 200, 200))
s1 = slider(2:length(xy), raw = true, camera = campixel!, start = 2)
lines!(sc, lift(i -> xy[1:i], s1[end][:value]), color = :black)
lines!(sc, lift(i -> xys[1:i], s1[end][:value]), color = :red)
scatter!(sc, lift(i -> i > tp ? [xys[tp]] : [Point(NaN, NaN)], s1[end][:value]), color = :blue, markersize = 5)
hbox(s1, sc)=#

