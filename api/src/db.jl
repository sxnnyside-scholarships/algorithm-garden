module Database

using Dates
using DBInterface
using LibPQ
using SQLite
using UUIDs
using ..CatalogSeed
using ..Config

export DbStore,
    open_store,
    close_store!,
    migrate_and_seed!,
    ping_db,
    db_exec,
    db_query,
    utc_now_iso

"""
    DbStore

Thread-safe SQLite or PostgreSQL database connection wrapper.
"""
mutable struct DbStore
    driver::String
    conn::Union{SQLite.DB, LibPQ.Connection}
    lock::ReentrantLock
    closed::Bool
end

utc_now_iso()::String = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SS") * "Z"

function _to_pg_placeholders(sql::AbstractString)::String
    io = IOBuffer()
    idx = 0
    in_single = false
    for ch in sql
        if ch == '\''
            in_single = !in_single
            write(io, ch)
        elseif ch == '?' && !in_single
            idx += 1
            write(io, '$')
            print(io, idx)
        else
            write(io, ch)
        end
    end
    return String(take!(io))
end

"""
    open_store(cfg::AppConfig) -> DbStore

Open the configured SQLite or PostgreSQL database connection.
"""
function open_store(cfg::AppConfig)::DbStore
    if cfg.db_driver == "sqlite"
        if cfg.sqlite_path != ":memory:"
            mkpath(dirname(cfg.sqlite_path))
        end
        db = SQLite.DB(cfg.sqlite_path)
        SQLite.execute(db, "PRAGMA foreign_keys = ON;")
        if cfg.sqlite_path != ":memory:"
            SQLite.execute(db, "PRAGMA journal_mode = WAL;")
        end
        return DbStore("sqlite", db, ReentrantLock(), false)
    else
        isempty(cfg.database_url) && error("DATABASE_URL is required when DB_DRIVER=postgres")
        conn = LibPQ.Connection(cfg.database_url)
        return DbStore("postgres", conn, ReentrantLock(), false)
    end
end

"""
    close_store!(store::DbStore)

Close the underlying database connection idempotently.
"""
function close_store!(store::DbStore)
    lock(store.lock) do
        store.closed && return
        store.closed = true
        if store.conn isa SQLite.DB
            SQLite.close(store.conn)
        else
            close(store.conn)
        end
    end
end

"""
    db_exec(store::DbStore, sql::AbstractString, params::Union{Tuple, AbstractVector} = ())

Execute a parameterized SQL statement against `store`.
"""
function db_exec(store::DbStore, sql::AbstractString, params::Union{Tuple, AbstractVector} = ())
    sql_str = String(sql)
    lock(store.lock) do
        store.closed && error("Database connection is closed")
        if store.conn isa SQLite.DB
            DBInterface.execute(store.conn, sql_str, collect(params))
        else
            LibPQ.execute(store.conn, _to_pg_placeholders(sql_str), collect(params))
        end
    end
end

"""
    db_query(store::DbStore, sql::AbstractString, params::Union{Tuple, AbstractVector} = ()) -> Vector{Dict{String, Any}}

Run a parameterized SQL query and normalize rows to dictionaries (`missing` -> `nothing`).
"""
function db_query(
    store::DbStore,
    sql::AbstractString,
    params::Union{Tuple, AbstractVector} = (),
)::Vector{Dict{String, Any}}
    sql_str = String(sql)
    lock(store.lock) do
        store.closed && error("Database connection is closed")
        res = if store.conn isa SQLite.DB
            DBInterface.execute(store.conn, sql_str, collect(params))
        else
            LibPQ.execute(store.conn, _to_pg_placeholders(sql_str), collect(params))
        end
        rows = Dict{String, Any}[]
        for row in res
            d = Dict{String, Any}()
            for col in propertynames(row)
                val = getproperty(row, col)
                d[String(col)] = val === missing ? nothing : val
            end
            push!(rows, d)
        end
        return rows
    end
end

function ping_db(store::DbStore)::Tuple{Bool, Int}
    t0 = time_ns()
    try
        lock(store.lock) do
            store.closed && return false, 0
            if store.driver == "sqlite"
                DBInterface.execute(store.conn, "SELECT 1")
            else
                LibPQ.execute(store.conn, "SELECT 1")
            end
            ms = max(0, round(Int, (time_ns() - t0) / 1e6))
            return true, ms
        end
    catch
        ms = max(0, round(Int, (time_ns() - t0) / 1e6))
        return false, ms
    end
end

function migrate_and_seed!(store::DbStore)
    ddl_statements = [
        """
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token_hash TEXT UNIQUE NOT NULL,
            expires_at TEXT NOT NULL,
            revoked_at TEXT,
            created_at TEXT NOT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS gardens (
            slug TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            sort_order INTEGER NOT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS algorithms (
            slug TEXT PRIMARY KEY,
            garden_slug TEXT NOT NULL REFERENCES gardens(slug) ON DELETE CASCADE,
            name TEXT NOT NULL,
            summary TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            concept TEXT NOT NULL,
            explanation TEXT NOT NULL,
            visualization_guide TEXT NOT NULL,
            default_params_json TEXT NOT NULL,
            reference_code TEXT NOT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS exercises (
            id TEXT PRIMARY KEY,
            algorithm_slug TEXT NOT NULL REFERENCES algorithms(slug) ON DELETE CASCADE,
            title TEXT NOT NULL,
            instructions TEXT NOT NULL,
            starter_code TEXT NOT NULL,
            test_cases_json TEXT NOT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS experiments (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            algorithm_slug TEXT NOT NULL REFERENCES algorithms(slug) ON DELETE CASCADE,
            title TEXT NOT NULL,
            code TEXT NOT NULL,
            params_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """,
    ]

    for stmt in ddl_statements
        db_exec(store, stmt)
    end

    for g in GARDENS_SEED
        db_exec(
            store,
            """
            INSERT INTO gardens (slug, name, description, sort_order)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(slug) DO UPDATE SET
                name = excluded.name,
                description = excluded.description,
                sort_order = excluded.sort_order
            """,
            (g.slug, g.name, g.description, g.sort_order),
        )
    end

    for a in ALGORITHMS_SEED
        db_exec(
            store,
            """
            INSERT INTO algorithms (
                slug, garden_slug, name, summary, difficulty,
                concept, explanation, visualization_guide,
                default_params_json, reference_code
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(slug) DO UPDATE SET
                garden_slug = excluded.garden_slug,
                name = excluded.name,
                summary = excluded.summary,
                difficulty = excluded.difficulty,
                concept = excluded.concept,
                explanation = excluded.explanation,
                visualization_guide = excluded.visualization_guide,
                default_params_json = excluded.default_params_json,
                reference_code = excluded.reference_code
            """,
            (
                a.slug,
                a.garden_slug,
                a.name,
                a.summary,
                a.difficulty,
                a.concept,
                strip(a.explanation),
                a.visualization_guide,
                a.default_params_json,
                strip(a.reference_code),
            ),
        )
    end

    for ex in EXERCISES_SEED
        db_exec(
            store,
            """
            INSERT INTO exercises (id, algorithm_slug, title, instructions, starter_code, test_cases_json)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                algorithm_slug = excluded.algorithm_slug,
                title = excluded.title,
                instructions = excluded.instructions,
                starter_code = excluded.starter_code,
                test_cases_json = excluded.test_cases_json
            """,
            (ex.id, ex.algorithm_slug, ex.title, ex.instructions, strip(ex.starter_code), ex.test_cases_json),
        )
    end
end

end

