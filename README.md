# Leon Schuermann's Website

This contains the source for the website hosted at
<https://leon.schuermann.io>.

None of this code is written with reusability in mind. It is
opinionated, not well documented, and probably not a good idea to take
inspiration from. But for anyone who's curious, feel free to take a
look at the Rube Goldberg machine that makes this site work.

## Accessing Page Data

The main site derivation features a passthru object that can be used
to gain access to the Nix page attrsets:

```
$ nix repl .
nix-repl> packages.x86_64-linux.default.pages.publications.export.venues.SOSP25.name
"The 31st ACM Symposium on Operating Systems Principles"
```

## Building and developing

```sh
nix build                       # production site in ./result
nix flake check                 # site validation, shell check, formatting
nix fmt                         # treefmt-nix
nix fmt -- --ci                 # check formatting without accepting changes
nix run .#preview               # drafts and live preview at localhost:8080
nix build .#preview             # preview output (no site validation)
nix flake update                # update input pins
```

## Deployment

Run `nix run .#deploy`. Requires a clean `public` branch, fetches `github`,
verifies that `github/public` is an ancestor of HEAD, checks formatting, and
builds the validated site in pure mode before pushing and uploading.
