{
  pkgs,
  formatter,
}:
pkgs.mkShell {
  name = "homepage-dev";

  buildInputs = with pkgs; [
    nix
    git
    formatter
    (python3.withPackages (pypkgs: with pypkgs; [ pyinotify ]))
  ];
}
