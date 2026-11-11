using GardenRunner

function _emit_json(obj)
    println(to_json(obj))
    flush(stdout)
end

function _process_raw(raw::AbstractString)
    loc = get(ENV, "GARDEN_LOCALE", "en")
    if isempty(strip(raw))
        _emit_json(
            Dict(
                "status" => "failed",
                "error" => Dict(
                    "category" => "contract_violation",
                    "message" => GardenRunner.RunnerI18n.rmsg("empty_payload"; locale = loc),
                    "line" => nothing,
                    "hint" => GardenRunner.RunnerI18n.rmsg("empty_payload_hint"; locale = loc),
                ),
            ),
        )
        return
    end

    payload = try
        parse_json(raw)
    catch err
        _emit_json(
            Dict(
                "status" => "failed",
                "error" => Dict(
                    "category" => "contract_violation",
                    "message" => GardenRunner.RunnerI18n.rmsg(
                        "malformed_json",
                        "err" => sprint(showerror, err);
                        locale = loc,
                    ),
                    "line" => nothing,
                    "hint" => GardenRunner.RunnerI18n.rmsg("malformed_json_hint"; locale = loc),
                ),
            ),
        )
        return
    end

    result = run_request(payload)
    _emit_json(result)
end

function main()
    if "--warm-one-shot" in ARGS
        # Handshake after sysimage/module init so the orchestrator knows this isolated worker is warm
        println("{\"ready\":true}")
        flush(stdout)
        eof(stdin) && return
        line = readline(stdin)
        isempty(strip(line)) && return
        _process_raw(line)
        return
    end

    raw = read(stdin, String)
    _process_raw(raw)
end

main()
