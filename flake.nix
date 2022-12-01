{
  description = "A basic rust flake with postgres";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustVersion = pkgs.rust-bin.stable.latest.default;
        psql_setup_file = pkgs.writeText "setup.sql" ''
                  DO
                  $do$
                  BEGIN
                    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE rolname = 'diesel') THEN
                      CREATE ROLE diesel CREATEDB LOGIN;
                    END IF;
                    CREATE DATABASE diesel_demo;
                  END
                  $do$
        '';
        postgres_setup = ''
                export PGDATA=$PWD/postgres_data
                export PGHOST=$PWD/postgres
                export LOG_PATH=$PWD/postgres/LOG
                export PGDATABASE=diesel_demo
                export DATABASE_CLEANER_ALLOW_REMOTE_DATABASE_URL=true
                if [ ! -d $PGHOST ]; then
                  mkdir -p $PGHOST
                fi
                if [ ! -d $PGDATA ]; then
                  echo 'Initializing postgresql database...'
                  LC_ALL=C.utf8 initdb $PGDATA --auth=trust >/dev/null
                fi
       '';
       start_postgres = pkgs.writeShellScriptBin "start_postgres" ''
         pg_ctl start -l $LOG_PATH -o "-c listen_addresses= -c unix_socket_directories=$PGHOST"
         psql -f ${psql_setup_file} > /dev/null
       '';
       stop_postgres = pkgs.writeShellScriptBin "stop_postgres" ''
         pg_ctl -D $PGDATA stop
       '';
      in {
        devShell = pkgs.mkShell {
          buildInputs = 
            [ 
              (rustVersion.override { extensions = [ "rust-src" ]; })
              pkgs.diesel-cli
              pkgs.postgresql
              start_postgres
              stop_postgres
            ];     
          shellHook = ''
            echo "setting up postgres"
            ${postgres_setup}
            echo "maybe run start_postgres if you can't connect"
          '';
        };
      });
}

