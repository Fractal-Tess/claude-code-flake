{ lib, package }:
{
  programs.claude-code = {
    enable = lib.mkEnableOption "Claude Code, Anthropic's terminal coding agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = package;
      description = "Claude Code package to install.";
    };
  };
}
