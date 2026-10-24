{
  description = "Nebula lighthouse OCI image built with Nix dockerTools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      nebula = pkgs.nebula;
      version = "1.11.2";
      fakeNss = pkgs.dockerTools.fakeNss.override {
        extraPasswdLines = [ "nebula:x:10001:10001:Nebula:/config:/noshell" ];
        extraGroupLines = [ "nebula:x:10001:" ];
      };
      runtimeCheck = pkgs.runCommand "nebula-runtime-contract" {
        nativeBuildInputs = [ pkgs.gnugrep ];
      } ''
        ${nebula}/bin/nebula -version 2>&1 | grep -F "Version: ${version}"
        test -x ${nebula}/bin/nebula-cert
        grep -F "nebula:x:10001:10001:" ${fakeNss}/etc/passwd
        grep -F "nebula:x:10001:" ${fakeNss}/etc/group
        touch "$out"
      '';
      image = assert nebula.version == version;
        pkgs.dockerTools.buildLayeredImage {
          name = "nebula-lighthouse";
          tag = version;
          contents = [
            nebula
            fakeNss
            pkgs.cacert
            pkgs.tzdata
          ];

          config = {
            User = "10001:10001";
            Entrypoint = [ "/nebula" ];
            Cmd = [ "-config" "/config/config.yml" ];
            Env = [
              "HOME=/tmp"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "PATH=${nebula}/bin"
              "TZDIR=${pkgs.tzdata}/share/zoneinfo"
            ];
            ExposedPorts = { "4242/udp" = { }; };
            Volumes = { "/config" = { }; };
            Labels = {
              "org.opencontainers.image.title" = "Nebula";
              "org.opencontainers.image.version" = version;
              "org.opencontainers.image.licenses" = "MIT";
              "org.opencontainers.image.source" = "https://github.com/slackhq/nebula";
              "org.opencontainers.image.description" = "Nix-built Nebula lighthouse daemon image";
            };
          };

          fakeRootCommands = ''
            mkdir -p ./config ./tmp
            ln -sfn ${nebula}/bin/nebula ./nebula
            ln -sfn ${nebula}/bin/nebula-cert ./nebula-cert
            chown -R 10001:10001 ./config
            chmod 0750 ./config
            chmod 1777 ./tmp
          '';
        };
    in {
      packages.${system} = {
        inherit image;
        default = image;
      };
      checks.${system} = {
        inherit image;
        runtime-contract = runtimeCheck;
      };
    };
}
