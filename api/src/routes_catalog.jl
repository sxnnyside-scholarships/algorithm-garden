module CatalogRoutes

using HTTP
using JSON3
using ..Database
using ..ApiI18n
using ..ApiErrors

export register_catalog_routes!

function register_catalog_routes!(register_fn, ctx)
    register_fn("GET", "/api/v1/gardens", function (_req::HTTP.Request)
        rows = db_query(
            ctx.db,
            """
            SELECT g.slug, g.name, g.description, COUNT(a.slug) AS algorithms_count
            FROM gardens g
            LEFT JOIN algorithms a ON a.garden_slug = g.slug
            GROUP BY g.slug, g.name, g.description, g.sort_order
            ORDER BY g.sort_order ASC
            """,
        )
        return json_ok(rows)
    end)

    register_fn("GET", "/api/v1/algorithms", function (req::HTTP.Request)
        qp = HTTP.queryparams(HTTP.URI(req.target))
        garden = get(qp, "garden", "")
        rows = if isempty(strip(garden))
            db_query(
                ctx.db,
                """
                SELECT slug, garden_slug AS garden, name, summary, difficulty
                FROM algorithms
                ORDER BY garden_slug ASC, name ASC
                """,
            )
        else
            db_query(
                ctx.db,
                """
                SELECT slug, garden_slug AS garden, name, summary, difficulty
                FROM algorithms
                WHERE garden_slug = ?
                ORDER BY name ASC
                """,
                (strip(garden),),
            )
        end
        return json_ok(rows)
    end)

    register_fn("GET", "/api/v1/algorithms/{slug}", function (_req::HTTP.Request, slug::String)
        rows = db_query(
            ctx.db,
            """
            SELECT slug, garden_slug AS garden, name, summary, difficulty,
                   concept, explanation, visualization_guide,
                   default_params_json, reference_code
            FROM algorithms
            WHERE slug = ?
            LIMIT 1
            """,
            (slug,),
        )
        isempty(rows) && throw(ApiException(404, "not_found", amsg("not_found_algo", "slug" => slug)))
        algo = copy(rows[1])
        algo["default_params"] = JSON3.read(String(pop!(algo, "default_params_json")), Dict{String, Any})

        ex_rows = db_query(
            ctx.db,
            """
            SELECT id, algorithm_slug, title, instructions, starter_code
            FROM exercises
            WHERE algorithm_slug = ?
            ORDER BY id ASC
            """,
            (slug,),
        )
        return json_ok(Dict("algorithm" => algo, "exercises" => ex_rows))
    end)
end

end

