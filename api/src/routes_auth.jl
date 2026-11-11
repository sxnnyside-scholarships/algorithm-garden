module AuthRoutes

using Dates
using HTTP
using UUIDs
using ..Database
using ..ApiI18n
using ..ApiErrors
using ..Security

export register_auth_routes!, authenticate_request, optional_authenticate

const EMAIL_RE = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"
const USERNAME_RE = r"^[a-zA-Z0-9_.-]{3,32}$"

function _public_user(row::Dict{String, Any})::Dict{String, Any}
    return Dict{String, Any}(
        "id" => row["id"],
        "email" => row["email"],
        "username" => row["username"],
        "role" => row["role"],
        "created_at" => row["created_at"],
    )
end

function _enforce_auth_rate_limit!(ctx, req::HTTP.Request, action::String)
    key = "auth:$(action):$(client_key(req))"
    allowed, retry_after = check_rate_limit!(ctx.limiter, key; limit=20, window_seconds=60)
    if !allowed
        throw(
            ApiException(
                429,
                "rate_limited",
                amsg("rate_limit_auth"),
                Dict("retry_after" => retry_after),
            ),
        )
    end
end

function _create_session(ctx, user_id::String)::String
    token = generate_bearer_token()
    tok_hash = hash_token(token, ctx.cfg.auth_token_secret)
    sid = string(uuid4())
    now_dt = now(UTC)
    created = Dates.format(now_dt, dateformat"yyyy-mm-ddTHH:MM:SS") * "Z"
    expires = Dates.format(now_dt + Second(ctx.cfg.token_ttl_seconds), dateformat"yyyy-mm-ddTHH:MM:SS") * "Z"

    db_exec(
        ctx.db,
        """
        INSERT INTO sessions (id, user_id, token_hash, expires_at, revoked_at, created_at)
        VALUES (?, ?, ?, ?, NULL, ?)
        """,
        (sid, user_id, tok_hash, expires, created),
    )
    return token
end

function optional_authenticate(ctx, req::HTTP.Request)::Union{Nothing, Dict{String, Any}}
    token = extract_bearer_token(req)
    token === nothing && return nothing
    tok_hash = hash_token(token, ctx.cfg.auth_token_secret)
    now_iso = utc_now_iso()

    rows = db_query(
        ctx.db,
        """
        SELECT u.id, u.email, u.username, u.role, u.created_at, s.id AS session_id
        FROM sessions s
        JOIN users u ON u.id = s.user_id
        WHERE s.token_hash = ? AND s.revoked_at IS NULL AND s.expires_at > ?
        LIMIT 1
        """,
        (tok_hash, now_iso),
    )
    isempty(rows) && return nothing
    return rows[1]
end

function authenticate_request(ctx, req::HTTP.Request)::Dict{String, Any}
    user = optional_authenticate(ctx, req)
    user === nothing && throw(ApiException(401, "unauthorized", amsg("unauthorized")))
    return user
end

function register_auth_routes!(register_fn, ctx)
    register_fn("POST", "/api/v1/auth/register", function (req::HTTP.Request)
        _enforce_auth_rate_limit!(ctx, req, "register")
        body = parse_json_body(req)
        email = lowercase(require_nonempty_str(body, "email"; max_len=254))
        username = require_nonempty_str(body, "username"; max_len=32)
        password = haskey(body, "password") && body["password"] isa AbstractString ? String(body["password"]) : ""

        details = Dict{String, String}()
        occursin(EMAIL_RE, email) || (details["email"] = amsg("field_email"))
        occursin(USERNAME_RE, username) || (details["username"] = amsg("field_username"))
        length(password) >= 8 || (details["password"] = amsg("field_min_len", "min" => 8))
        length(password) <= 128 || (details["password"] = amsg("field_max_len", "max" => 128))
        isempty(details) || throw(ApiException(422, "validation_failed", amsg("validation_failed"), details))

        existing = db_query(
            ctx.db,
            "SELECT id FROM users WHERE email = ? OR username = ? LIMIT 1",
            (email, username),
        )
        isempty(existing) || throw(ApiException(409, "conflict", amsg("conflict_account")))

        user_id = string(uuid4())
        created_at = utc_now_iso()
        pw_hash = hash_password(password, ctx.cfg.pbkdf2_iterations)

        db_exec(
            ctx.db,
            """
            INSERT INTO users (id, email, username, password_hash, role, created_at)
            VALUES (?, ?, ?, ?, 'student', ?)
            """,
            (user_id, email, username, pw_hash, created_at),
        )

        token = _create_session(ctx, user_id)
        user_row = Dict{String, Any}(
            "id" => user_id,
            "email" => email,
            "username" => username,
            "role" => "student",
            "created_at" => created_at,
        )
        return json_ok(Dict("user" => _public_user(user_row), "token" => token); status=201)
    end)

    register_fn("POST", "/api/v1/auth/login", function (req::HTTP.Request)
        _enforce_auth_rate_limit!(ctx, req, "login")
        body = parse_json_body(req)
        email = lowercase(require_nonempty_str(body, "email"; max_len=254))
        password = haskey(body, "password") && body["password"] isa AbstractString ? String(body["password"]) : ""
        isempty(password) &&
            throw(ApiException(422, "validation_failed", amsg("validation_failed"), Dict("password" => amsg("field_required"))))

        rows = db_query(
            ctx.db,
            "SELECT id, email, username, password_hash, role, created_at FROM users WHERE email = ? LIMIT 1",
            (email,),
        )
        if isempty(rows) || !verify_password(password, String(rows[1]["password_hash"]))
            throw(ApiException(401, "unauthorized", amsg("invalid_credentials")))
        end

        user = rows[1]
        token = _create_session(ctx, String(user["id"]))
        return json_ok(Dict("user" => _public_user(user), "token" => token))
    end)

    register_fn("POST", "/api/v1/auth/logout", function (req::HTTP.Request)
        user = authenticate_request(ctx, req)
        db_exec(
            ctx.db,
            "UPDATE sessions SET revoked_at = ? WHERE id = ?",
            (utc_now_iso(), user["session_id"]),
        )
        return json_ok(Dict("revoked" => true))
    end)

    register_fn("GET", "/api/v1/auth/me", function (req::HTTP.Request)
        user = authenticate_request(ctx, req)
        return json_ok(Dict("user" => _public_user(user)))
    end)
end

end

