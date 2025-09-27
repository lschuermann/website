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
$ nix repl --argstr gitRev "$(git rev-parse HEAD)" --file site.nix
Lix 2.91.3
Type :? for help.
Loading installable ''...
Added 43 variables.
nix-repl> pages.publications.export.venues.SOSP25.name
"The 31st ACM Symposium on Operating Systems Principles"
```
