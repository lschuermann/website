{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "homepage-dev";

  buildInputs = with pkgs; [
    (python3.withPackages (pypkgs: with pypkgs; [
      pyinotify
    ]))
  ];
}
