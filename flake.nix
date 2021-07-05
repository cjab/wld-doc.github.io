{
  description = "An Elixir client for Google Pub/Sub";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, ... }:
    let
      name = "wld-doc";
    in
    utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlay = [ ];
          };
        in
        rec {
          devShell = pkgs.mkShell
            {
              nativeBuildInputs = with pkgs; [ ];
              buildInputs = with pkgs; [
                direnv
                nodejs
                yarn
              ];
            };
        }
      );
}
