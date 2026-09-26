{
  description = "Claude Code packaged for Nix from Anthropic's official native builds";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Claude Code ships under Anthropic's commercial terms, so the package is
      # unfree. Allow it here so `nix run` and `nix flake check` work without
      # the caller having to relax their own nixpkgs config.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      packageFor = system: (pkgsFor system).callPackage ./packages/claude-code.nix { };
    in
    {
      packages = forAllSystems (
        system:
        let
          claude-code = packageFor system;
        in
        {
          inherit claude-code;
          default = claude-code;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.claude-code}/bin/claude";
          meta.description = "Run Claude Code";
        };
      });

      checks = forAllSystems (system: {
        claude-code = self.packages.${system}.claude-code;
      });

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);

      overlays.default = final: _previous: {
        claude-code = final.callPackage ./packages/claude-code.nix { };
      };

      nixosModules.default = import ./modules/nixos.nix { inherit self; };
      homeManagerModules.default = import ./modules/home-manager.nix { inherit self; };
    };
}
