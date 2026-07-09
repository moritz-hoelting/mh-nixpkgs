# `mensa-upb-api`

`mensa-upb-api` provides tools for fetching meal data from the Paderborn University's canteens and exposing it through a clean HTTP API.

The package contains three binaries:

| Binary              | Description                                                                                           |
| ------------------- | ----------------------------------------------------------------------------------------------------- |
| `mensa-upb-api`     | Starts the HTTP API server.                                                                           |
| `mensa-upb-scraper` | Fetches menu data and stores it in the configured PostgreSQL database.                                |
| `scraper-cli`       | Command-line interface for interacting with the scraper manually. Useful for testing and development. |

All binaries are installed into `${packages.${system}.mensa-upb-api}/bin/`.

## NixOS module

The package provides the `services.mensa-upb-api` NixOS module.

By default, enabling the module:

* starts the API server,
* configures a PostgreSQL database,
* creates a dedicated PostgreSQL user,
* runs the scraper periodically using a systemd timer,

## Example

```nix
{
  services.mensa-upb-api = {
    enable = true;

    interface = "0.0.0.0";
    port = 8080;

    corsAllowed = [
      "https://example.com"
    ];

    excludedCanteens = [
      "forum"
    ];
  };
}
```

## Options

### `services.mensa-upb-api.enable`

Enable the Mensa UPB API service.

**Default:** `false`

---

### `services.mensa-upb-api.package`

Package providing the service binaries.

**Default:** `pkgs.mensa-upb-api`

---

### `services.mensa-upb-api.configurePostgresql`

Whether the module should configure and manage a PostgreSQL instance for the service.

Disable this if you already have an existing PostgreSQL server.

**Default:** `true`

---

### `services.mensa-upb-api.logLevel`

Controls the verbosity of application logging.

Possible values:

* `trace`
* `debug`
* `info`
* `warn`
* `error`

**Default:** `warn`

---

### `services.mensa-upb-api.interface`

Interface the API listens on.

**Default:** `localhost`

---

### `services.mensa-upb-api.port`

Port the API listens on.

**Default:** `8080`

---

### `services.mensa-upb-api.databaseUrl`

Connection string for the PostgreSQL database.

The value is passed directly to SQLx.
See the [SQLx PostgreSQL connection documentation](https://docs.rs/sqlx/latest/sqlx/postgres/struct.PgConnectOptions.html) for supported formats.

**Default:**

```text
postgres://mensa_upb@%2Frun%2Fpostgresql/mensa_upb
```

---

### `services.mensa-upb-api.corsAllowed`

List of allowed origins for CORS.

If left as `null`, no CORS headers are configured.

Example:

```nix
corsAllowed = [
  "https://example.com"
  "https://app.example.com"
];
```

To allow every origin:

```nix
corsAllowed = [ "*" ];
```

---

### `services.mensa-upb-api.rateLimit`

Configuration for API rate limiting.

#### `seconds`

Time window (in seconds) after which tokens are replenished.

**Default:** `5`

#### `burst`

Maximum number of requests allowed in one burst.

**Default:** `5`

Example:

```nix
rateLimit = {
  seconds = 10;
  burst = 20;
};
```

---

### `services.mensa-upb-api.useXForwardedHost`

Whether the API should use the `X-Forwarded-Host` header to determine the client IP address.

Enable this when the API is behind a reverse proxy that forwards client information.

**Default:** `true`

---

### `services.mensa-upb-api.excludedCanteens`

List of canteens that should not be scraped.

Available values:

* `forum`
* `academica`
* `grillcafe`
* `zm2`
* `basilica`
* `atrium`

By default, all canteens are scraped.

Example:

```nix
excludedCanteens = [
  "forum"
  "grillcafe"
];
```

---

### `services.mensa-upb-api.scraper.enable`

Whether the scraper should run periodically as a separate systemd service and timer.

When disabled, the API is started without scheduled scraping.

**Default:** `true`

---

### `services.mensa-upb-api.scraper.schedule`

systemd calendar expression specifying when the scraper runs.

**Default:**

```text
*-*-* 00,08:00:00
```

Example:

```nix
scraper.schedule = "*-*-* 06:00:00";
```

See [`systemd.time(7)`](https://man.archlinux.org/man/systemd.time.7.en#CALENDAR_EVENTS) for the supported calendar syntax.
