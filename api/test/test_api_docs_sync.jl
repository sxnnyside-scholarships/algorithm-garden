@testset "ApiDocsSync" begin
    ctx = make_test_ctx()
    try
        api_md_path = joinpath(dirname(dirname(@__DIR__)), "API.md")
        @test isfile(api_md_path)
        api_md = read(api_md_path, String)

        for (method, path) in ctx.registered_routes
            doc_path = replace(path, r"\{([a-zA-Z0-9_]+)\}" => s":\1")
            needle = "`$method $doc_path`"
            @test occursin(needle, api_md)
        end
    finally
        close_store!(ctx.db)
    end
end

