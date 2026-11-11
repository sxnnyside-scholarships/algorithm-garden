module ExecutionRoutes

using HTTP
using JSON3
using ..Database
using ..ApiI18n
using ..ApiErrors
using ..AuthRoutes
using ..Security

export register_execution_routes!

const MAX_CODE_BYTES = 32_768

function _enforce_exec_rate_limit!(ctx, req::HTTP.Request, user)
    id_part = user === nothing ? "ip:" * client_key(req) : "user:" * String(user["id"])
    limit = user === nothing ? 20 : 60
    allowed, retry_after = check_rate_limit!(ctx.limiter, "exec:$(id_part)"; limit=limit, window_seconds=60)
    if !allowed
        throw(
            ApiException(
                429,
                "rate_limited",
                amsg("rate_limit_exec"),
                Dict("retry_after" => retry_after),
            ),
        )
    end
end

function _validate_code(body::Dict{String, Any})::String
    if !haskey(body, "code") || !(body["code"] isa AbstractString)
        throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("code" => amsg("field_string"))))
    end
    code = String(body["code"])
    isempty(strip(code)) &&
        throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("code" => amsg("field_nonempty"))))
    ncodeunits(code) > MAX_CODE_BYTES &&
        throw(
            ApiException(
                422,
                "validation_failed",
                amsg("validation_failed"),
                Dict("code" => amsg("field_max_bytes", "max" => MAX_CODE_BYTES)),
            ),
        )
    return code
end

function _run_with_guard(ctx, payload::Dict{String, Any})::Dict{String, Any}
    try
        return ctx.exec_runner_fn(ctx.cfg, payload)
    catch
        throw(ApiException(503, "runner_unavailable", amsg("runner_unavailable")))
    end
end

function register_execution_routes!(register_fn, ctx)
    register_fn("POST", "/api/v1/executions", function (req::HTTP.Request)
        user = optional_authenticate(ctx, req)
        _enforce_exec_rate_limit!(ctx, req, user)
        body = parse_json_body(req)
        slug = require_nonempty_str(body, "algorithm_slug"; max_len=128)
        code = _validate_code(body)

        rows = db_query(
            ctx.db,
            "SELECT slug, garden_slug, default_params_json FROM algorithms WHERE slug = ? LIMIT 1",
            (slug,),
        )
        isempty(rows) && throw(ApiException(404, "not_found", amsg("not_found_algo", "slug" => slug)))
        algo = rows[1]

        params = if haskey(body, "params") && body["params"] !== nothing
            body["params"] isa Dict ||
                throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("params" => amsg("field_object"))))
            body["params"]
        else
            JSON3.read(String(algo["default_params_json"]), Dict{String, Any})
        end

        payload = Dict{String, Any}(
            "garden" => algo["garden_slug"],
            "algorithm" => algo["slug"],
            "code" => code,
            "params" => params,
            "locale" => current_api_locale(),
        )
        result = _run_with_guard(ctx, payload)
        return json_ok(Dict("execution" => result))
    end)

    register_fn("POST", "/api/v1/exercises/{id}/verify", function (req::HTTP.Request, id::String)
        user = authenticate_request(ctx, req)
        _enforce_exec_rate_limit!(ctx, req, user)
        body = parse_json_body(req)
        code = _validate_code(body)

        rows = db_query(
            ctx.db,
            """
            SELECT e.id, e.algorithm_slug, e.test_cases_json,
                   a.garden_slug, a.default_params_json
            FROM exercises e
            JOIN algorithms a ON a.slug = e.algorithm_slug
            WHERE e.id = ?
            LIMIT 1
            """,
            (id,),
        )
        isempty(rows) && throw(ApiException(404, "not_found", amsg("not_found_exercise", "id" => id)))
        ex = rows[1]

        default_params = JSON3.read(String(ex["default_params_json"]), Dict{String, Any})
        test_cases = JSON3.read(String(ex["test_cases_json"]), Vector{Dict{String, Any}})

        payload = Dict{String, Any}(
            "garden" => ex["garden_slug"],
            "algorithm" => ex["algorithm_slug"],
            "code" => code,
            "params" => default_params,
            "tests" => test_cases,
            "locale" => current_api_locale(),
        )
        result = _run_with_guard(ctx, payload)
        tests_out = get(result, "tests", nothing)
        passed =
            get(result, "status", "") == "completed" &&
            tests_out isa AbstractVector &&
            !isempty(tests_out) &&
            all(t -> get(t, "passed", false) === true, tests_out)

        return json_ok(
            Dict(
                "passed" => passed,
                "results" => tests_out === nothing ? Any[] : tests_out,
                "execution" => result,
            ),
        )
    end)
end

end

