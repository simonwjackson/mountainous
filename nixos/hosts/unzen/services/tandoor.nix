{ config, pkgs, age, ... }:

{
  age.secrets.tandoor_env.file = ../../../../secrets/tandoor_env.age;

  virtualisation.oci-containers.containers = {
    # TODO: Move vod2pod
    # vod2pod_web = {
    #   autoStart = true;
    #   dependsOn = [ "vod2pod_redis" ];
    #   ports = [ "0.0.0.0:7062:8080" ];
    #   image = "madiele/vod2pod-rss";
    #   environment = {
    #     TZ = "America/Chicago";
    #     MP3_BITRATE = "192";
    #     TRANSCODE = "true"; #put to false if you only need feed generation
    #     RUST_LOG = "INFO"; #set to DEBUG if you are having problems than open a github issue with the logs, use "sudo docker compose logs" to print them
    #     SUBFOLDER = "/"; #for reverse proxies, ex: "/" -> access the app at mywebsite.com ; "vod2pod" -> access at mywebsite.com/vod2pod
    #     TWITCH_TO_PODCAST_URL = "ttprss"; #don't edit this
    #     PODTUBE_URL = "http://podtube:15000"; #don't edit this
    #     REDIS_ADDRESS = "vod2pod_redis";
    #     REDIS_PORT = "6379"; #don't edit this
    #   };
    # };
    #
    # vod2pod_redis = {
    #   autoStart = true;
    #   cmd = [ "redis-server --save 20 1 --loglevel warning" ];
    #   image = "redis:6.2";
    # };

    tandoor_db = {
      autoStart = true;
      image = "postgres:15-alpine";
      environmentFiles = [
        config.age.secrets.tandoor_env.path
      ];
      environment = {
        DB_ENGINE = "django.db.backends.postgresql";
        POSTGRES_HOST = "db_recipes";
        POSTGRES_PORT = "5432";
        POSTGRES_USER = "djangodb";
        POSTGRES_DB = "djangodb";
      };
      volumes = [
        "/glacier/snowscape/services/tandoor/postgresql:/var/lib/postgresql/data"
      ];
    };

    tandoor_web = {
      autoStart = true;
      image = "vabene1111/recipes";
      environmentFiles = [
        config.age.secrets.tandoor_env.path
      ];
      environment = {
        DB_ENGINE = "django.db.backends.postgresql";
        POSTGRES_HOST = "tandoor_db";
        POSTGRES_PORT = "5432";
        POSTGRES_USER = "djangodb";
        POSTGRES_DB = "djangodb";
      };
      ports = [ "0.0.0.0:7426:8080" ];
      volumes = [
        "/glacier/snowscape/services/tandoor/mediafiles:/opt/recipes/mediafiles"
        "/glacier/snowscape/services/tandoor/staticfiles:/opt/recipes/staticfiles"
        # Do not make this a bind mount, see https://docs.tandoor.dev/install/docker/#volumes-vs-bind-mounts
        # "nginx_config:/opt/recipes/nginx/conf.d"
      ];
      dependsOn = [ "tandoor_db" ];
    };
  };
}
