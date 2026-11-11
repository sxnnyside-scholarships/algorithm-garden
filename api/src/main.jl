using GardenApi

function main()
    cfg = load_config()
    @info "Starting Algorithm Garden API" host = cfg.host port = cfg.port db_driver = cfg.db_driver runner_mode = cfg.runner_mode
    start_server(cfg; async=false)
end

main()

