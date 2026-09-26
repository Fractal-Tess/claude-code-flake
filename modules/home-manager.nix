{ self }:
{
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  # Home Manager already declares a full `programs.claude-code` module with
  # settings, agents, commands, and MCP server options. Redeclaring it here
  # would collide, so this module only points that module at the flake's
  # package. Enable and configure Claude Code through Home Manager as usual.
  config.programs.claude-code.package = lib.mkDefault self.packages.${system}.claude-code;
}
