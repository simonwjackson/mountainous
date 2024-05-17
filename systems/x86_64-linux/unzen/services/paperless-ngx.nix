{
  age,
  config,
  pkgs,
  ...
}: {
  # age.secrets.paperless_ngx_env.file = ../../../../secrets/paperless_ngx_env.age;

  virtualisation.oci-containers.containers = {
    paperless-ngx_broker = {
      image = "docker.io/library/redis:7";
      autoStart = true;
      volumes = [
        "redisdata:/data"
      ];
    };

    paperless-ngx_db = {
      image = "docker.io/library/postgres:15";
      autoStart = true;
      volumes = [
        "/glacier/snowscape/services/paperless-ngx/postgres:/var/lib/postgresql/data"
      ];
      environmentFiles = [
        config.age.secrets.paperless_ngx_env.path
      ];
      environment = {
        POSTGRES_DB = "paperless";
        POSTGRES_USER = "paperless";
      };
    };

    paperless-ngx_web = {
      image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
      autoStart = true;
      dependsOn = [
        "paperless-ngx_db"
        "paperless-ngx_broker"
      ];
      ports = ["0.0.0.0:9493:8000"];
      volumes = [
        "/glacier/snowscape/services/paperless-ngx/data:/usr/src/paperless/data"
        "/glacier/snowscape/services/paperless-ngx/media:/usr/src/paperless/media"
        "/glacier/snowscape/services/paperless-ngx/export:/usr/src/paperless/export"
        "/glacier/snowscape/services/paperless-ngx/consume:/usr/src/paperless/consume"
      ];
      environmentFiles = [
        config.age.secrets.paperless_ngx_env.path
      ];
      environment = {
        # TODO: Tie this into main user
        USERMAP_UID = "1000";
        USERMAP_GID = "1000";
        PAPERLESS_REDIS = "redis://paperless-ngx_broker:6379";
        PAPERLESS_DBHOST = "paperless-ngx_db";
        # PAPERLESS_AUTO_LOGIN_USERNAME = "simonwjackson";
        PAPERLESS_ADMIN_USER = "simonwjackson";
        PAPERLESS_ADMIN_MAIL = "simon.jackson@gmail.com";
        PAPERLESS_URL = "http://unzen:9493";
        PAPERLESS_CSRF_TRUSTED_ORIGINS = "http://unzen:9493";
        # PAPERLESS_CORS_ALLOWED_HOSTS = "*";
        #PAPERLESS_TIME_ZONE = "America/Chicago";
        # PAPERLESS_SECRET_KEY = "";
        # PAPERLESS_ALLOWED_HOSTS=.yourdomain.com  ## If you have multiple subdomains pointing towards it
        # PAPERLESS_CSRF_TRUSTED_ORIGINS=https://*.yourdomain.com  ## If you have multiple subdomains pointing towards it
      };
    };
  };
}
