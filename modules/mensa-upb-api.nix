{ packages }:
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.services.mensa-upb-api;
in
{
  options.services.mensa-upb-api = {
    enable = lib.mkEnableOption "Mensa UPB API";

    package = lib.mkOption {
      type = lib.types.package;
      default = packages.${pkgs.stdenv.hostPlatform.system}.mensa-upb-api;
      description = "Package to use for the Mensa UPB API service";
    };

    configurePostgresql = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enables and configures the postgresql service to work for this service";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "trace"
        "debug"
        "info"
        "warn"
        "error"
      ];
      default = "warn";
      description = "Verbosity of logging";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Interface to listen on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };

    databaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "postgres://mensa_upb@%2Frun%2Fpostgresql/mensa_upb";
      description = lib.mkDoc ''
        Database URL of the postgresql instance to use.

        See [sqlx documentation](https://docs.rs/sqlx/latest/sqlx/postgres/struct.PgConnectOptions.html) for details.
      '';
    };

    corsAllowed = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      example = [
        "https://foo.com"
        "https://bar.com"
      ];
      description = lib.mkdocs ''
        List of hosts to set the CORS headers to.

        Set to `*` to allow all.
      '';
    };

    rateLimit = lib.mkOption {
      type = lib.types.submodule {
        options = {
          seconds = lib.mkOption {
            type = lib.types.int;
            default = 5;
            description = "The time in seconds after which the rate limit should replenish";
          };

          burst = lib.mkOption {
            type = lib.types.int;
            default = 5;
            description = "The maximum number of requests that can be made in a burst";
          };
        };
      };
      default = { };
      description = "API rate limiting configuration.";
    };

    useXForwardedHost = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to use the `X-Forwarded-Host` header for client ip";
    };

    excludedCanteens = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.listOf (
          lib.types.enum [
            "forum"
            "academica"
            "grillcafe"
            "zm2"
            "basilica"
            "atrium"
          ]
        )
      );
      default = null;
      description = "Which canteens to skip scraping";
    };

    scraper = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether the scraper runs separately to the API server on a schedule";
          };

          schedule = lib.mkOption {
            type = lib.types.str;
            default = "*-*-* 00,08:00:00";
            description = lib.mkdocs ''
              When to run the scraper.

              Needs to be in the [format required by systemd](https://man.archlinux.org/man/systemd.time.7.en#CALENDAR_EVENTS).
            '';
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      escapedDatabaseUrl = builtins.replaceStrings [ "%" ] [ "%%" ] cfg.databaseUrl;
    in
    {
      systemd =
        let
          sharedServiceConfig = {
            DynamicUser = true;
            User = "mensa_upb";
            Group = "mensa_upb";
            NoNewPrivileges = true;

            PrivateTmp = true;
            PrivateDevices = true;

            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectHostname = true;
            ProtectClock = true;

            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;

            MemoryDenyWriteExecute = true;
            LockPersonality = true;

            CapabilityBoundingSet = "";
            DevicePolicy = "closed";

            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
            ];

            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];

            UMask = "0077";
          };
          joinedExcludedCanteens = lib.optionalString (
            cfg.excludedCanteens != null && cfg.excludedCanteens != [ ]
          ) (lib.concatStringsSep "," cfg.excludedCanteens);
        in
        {
          services.mensa-upb-api = {
            description = "Mensa UPB API";

            wantedBy = [ "multi-user.target" ];

            environment = {
              DATABASE_URL = escapedDatabaseUrl;
              API_INTERFACE = cfg.interface;
              API_PORT = toString cfg.port;
              API_CORS_ALLOWED = lib.optionalString (cfg.corsAllowed != null && cfg.corsAllowed != [ ]) (
                lib.concatStringsSep "," cfg.corsAllowed
              );
              API_RATE_LIMIT_SECONDS = toString cfg.rateLimit.seconds;
              API_RATE_LIMIT_BURST = toString cfg.rateLimit.burst;
              API_USE_X_FORWARDED_HOST = toString cfg.useXForwardedHost;
              FILTER_CANTEENS = joinedExcludedCanteens;
              RUST_LOG = "none,mensa_upb_api=${cfg.logLevel}";
            };

            serviceConfig = sharedServiceConfig // {
              ExecStart = lib.getExe cfg.package;
              Restart = "always";

              StateDirectory = "mensa-upb-api";
            };
          };

          timers."mensa-upb-scraper" = lib.mkIf cfg.scraper.enable {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = cfg.scraper.schedule;
              Persistent = true;
              Unit = "mensa-upb-scraper.service";
            };
          };

          services."mensa-upb-scraper" = lib.mkIf cfg.scraper.enable {
            environment = {
              DATABASE_URL = escapedDatabaseUrl;
              RUST_LOG = "none,mensa_upb_scraper=${cfg.logLevel}";
              FILTER_CANTEENS = joinedExcludedCanteens;
            };

            serviceConfig = sharedServiceConfig // {
              ExecStart = "${cfg.package}/bin/mensa-upb-scraper";
              Type = "oneshot";
            };
          };
        };

      services.postgresql = lib.mkIf cfg.configurePostgresql {
        enable = true;

        ensureDatabases = [ "mensa_upb" ];

        ensureUsers = [
          {
            name = "mensa_upb";
            ensureDBOwnership = true;
          }
        ];
      };
    }
  );
}
