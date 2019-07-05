using Documenter, DungAnalyse

makedocs(
    modules = [DungAnalyse],
    format = :html,
    sitename = "DungAnalyse.jl",
    pages = Any["index.md"]
)

deploydocs(
    repo = "github.com/yakir12/DungAnalyse.jl.git",
    target = "build",
    julia = "1.0",
    deps = nothing,
    make = nothing,
)
