plothomingsearching(filter(kv -> haskey(last(kv).runs[1].metadata.setup, :displace_direction), trackdata), :displace_direction)

# TODO 
# you have to change the nest to originalnest becuase in dispalced there is a originalnest but in transfer they might not be...
# basically, I need to make sure that these  functions work for any combination of experiments, wihch might mean that I need to rethink what should be missing and what should not, or maybe have different summary functions for diffeent experiments
# find more bad runs and say what's wrong with them


trackdata = JLSO.load(joinpath(coffeesource, "trackdata.jlso"))
badruns = [DateTime(2017,11,17,8,54), # the particle filter really fails there
           DateTime(2017,11,15,11,44) # the turningpoint is detected way too early
          ]
kill = Pair{String, Int}[]
for (experimentid, v) in data, (i, r) in enumerate(v.runs)
    if start(r.data[:track].data.video) ∈ badruns
        push!(kill, experimentid => i)
    end
end
for (experimentid,i) in kill
    deleteat!(trackdata[experimentid].runs, i)
end

for (k,v) in filter(kv -> haskey(last(kv).runs[1].metadata.setup, :transfer), trackdata)
    plothomingsearching(Dict(k => v), :transfer)
end


for (k,v) in filter(kv -> first(kv) == "nest#closed person#therese", trackdata)
    plothomingsearching(Dict(k => v), :nest_coverage)
end


