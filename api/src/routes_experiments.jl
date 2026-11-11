module ExperimentRoutes

using HTTP
using JSON3
using UUIDs
using ..Database
using ..ApiI18n
using ..ApiErrors
using ..AuthRoutes

export register_experiment_routes!

function _format_experiment(row::Dict{String, Any})::Dict{String, Any}
    return Dict{String, Any}(
        "id" => row["id"],
        "user_id" => row["user_id"],
        "algorithm_slug" => row["algorithm_slug"],
        "title" => row["title"],
        "code" => row["code"],
        "params" => JSON3.read(String(row["params_json"]), Dict{String, Any}),
        "created_at" => row["created_at"],
        "updated_at" => row["updated_at"],
    )
end

function _load_owned_experiment(ctx, id::String, user_id::String)::Dict{String, Any}
    rows = db_query(
        ctx.db,
        """
        SELECT id, user_id, algorithm_slug, title, code, params_json, created_at, updated_at
        FROM experiments
        WHERE id = ?
        LIMIT 1
        """,
        (id,),
    )
    isempty(rows) && throw(ApiException(404, "not_found", amsg("not_found_experiment", "id" => id)))
    row = rows[1]
    String(row["user_id"]) == user_id ||
        throw(ApiException(403, "forbidden", amsg("forbidden_experiment")))
    return row
end

function register_experiment_routes!(register_fn, ctx)
    register_fn("GET", "/api/v1/experiments", function (req::HTTP.Request)
        user = authenticate_request(ctx, req)
        rows = db_query(
            ctx.db,
            """
            SELECT id, user_id, algorithm_slug, title, code, params_json, created_at, updated_at
            FROM experiments
            WHERE user_id = ?
            ORDER BY updated_at DESC
            """,
            (user["id"],),
        )
        return json_ok([_format_experiment(r) for r in rows])
    end)

    register_fn("POST", "/api/v1/experiments", function (req::HTTP.Request)
        user = authenticate_request(ctx, req)
        body = parse_json_body(req)
        algo_slug = require_nonempty_str(body, "algorithm_slug"; max_len=128)
        title = require_nonempty_str(body, "title"; max_len=120)
        code = haskey(body, "code") && body["code"] isa AbstractString ? String(body["code"]) : ""
        isempty(strip(code)) &&
            throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("code" => amsg("field_nonempty"))))
        ncodeunits(code) > 32_768 &&
            throw(
                ApiException(
                    422,
                    "validation_failed",
                    amsg("validation_failed"),
                    Dict("code" => amsg("field_max_bytes", "max" => 32_768)),
                ),
            )

        algo_rows = db_query(ctx.db, "SELECT slug, default_params_json FROM algorithms WHERE slug = ? LIMIT 1", (algo_slug,))
        isempty(algo_rows) && throw(ApiException(404, "not_found", amsg("not_found_algo", "slug" => algo_slug)))

        params_json = if haskey(body, "params") && body["params"] !== nothing
            body["params"] isa Dict ||
                throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("params" => amsg("field_object"))))
            JSON3.write(body["params"])
        else
            String(algo_rows[1]["default_params_json"])
        end

        exp_id = string(uuid4())
        now_iso = utc_now_iso()
        db_exec(
            ctx.db,
            """
            INSERT INTO experiments (id, user_id, algorithm_slug, title, code, params_json, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (exp_id, user["id"], algo_slug, title, code, params_json, now_iso, now_iso),
        )
        row = _load_owned_experiment(ctx, exp_id, String(user["id"]))
        return json_ok(Dict("experiment" => _format_experiment(row)); status=201)
    end)

    register_fn("GET", "/api/v1/experiments/{id}", function (req::HTTP.Request, id::String)
        user = authenticate_request(ctx, req)
        row = _load_owned_experiment(ctx, id, String(user["id"]))
        return json_ok(Dict("experiment" => _format_experiment(row)))
    end)

    register_fn("PATCH", "/api/v1/experiments/{id}", function (req::HTTP.Request, id::String)
        user = authenticate_request(ctx, req)
        existing = _load_owned_experiment(ctx, id, String(user["id"]))
        body = parse_json_body(req)

        title = haskey(body, "title") ? require_nonempty_str(body, "title"; max_len=120) : String(existing["title"])
        code = if haskey(body, "code")
            body["code"] isa AbstractString ||
                throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("code" => amsg("field_string"))))
            c = String(body["code"])
            isempty(strip(c)) &&
                throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("code" => amsg("field_nonempty"))))
            ncodeunits(c) > 32_768 &&
                throw(
                    ApiException(
                        422,
                        "validation_failed",
                        amsg("validation_failed"),
                        Dict("code" => amsg("field_max_bytes", "max" => 32_768)),
                    ),
                )
            c
        else
            String(existing["code"])
        end

        params_json = if haskey(body, "params")
            body["params"] isa Dict ||
                throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("params" => amsg("field_object"))))
            JSON3.write(body["params"])
        else
            String(existing["params_json"])
        end

        now_iso = utc_now_iso()
        db_exec(
            ctx.db,
            """
            UPDATE experiments
            SET title = ?, code = ?, params_json = ?, updated_at = ?
            WHERE id = ? AND user_id = ?
            """,
            (title, code, params_json, now_iso, id, user["id"]),
        )
        updated = _load_owned_experiment(ctx, id, String(user["id"]))
        return json_ok(Dict("experiment" => _format_experiment(updated)))
    end)

    register_fn("DELETE", "/api/v1/experiments/{id}", function (req::HTTP.Request, id::String)
        user = authenticate_request(ctx, req)
        _load_owned_experiment(ctx, id, String(user["id"]))
        db_exec(ctx.db, "DELETE FROM experiments WHERE id = ? AND user_id = ?", (id, user["id"]))
        return json_ok(Dict("deleted" => true))
    end)
end

end

