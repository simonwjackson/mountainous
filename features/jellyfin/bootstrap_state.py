def wait_for_startup_state(api_request, *, sleep, attempts=60, known_initialized=False):
    """Wait until Jellyfin exposes either its initialized or first-run API."""
    last_error = None

    for _ in range(attempts):
        try:
            public_info = api_request("/System/Info/Public")
        except Exception as error:
            last_error = error
            sleep(1)
            continue

        if public_info is None:
            sleep(1)
            continue

        if bool(public_info.get("StartupWizardCompleted")):
            return "initialized", public_info, None

        if known_initialized:
            sleep(1)
            continue

        try:
            startup_configuration = api_request("/Startup/Configuration")
        except Exception as error:
            last_error = error
        else:
            return "first-run", public_info, startup_configuration

        sleep(1)

    error = RuntimeError("Timed out waiting for Jellyfin startup state")
    if last_error is not None:
        raise error from last_error
    raise error
