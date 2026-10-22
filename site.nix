{
  pkgs,
  gitRev,
  baseUrl ? "https://leon.schuermann.io",
  doCheck ? true,
  renderBlogDrafts ? false,
}:

with pkgs;
with import ./util.nix pkgs;

let

  site_page_args = {
    inherit pkgs lib gitRev;

    util = import ./util.nix pkgs;

    urlPrefix = baseUrl;
    assetsPath = "/assets/";

    headerNavPages = [
      {
        id = "index";
        title = "Home";
      }
      {
        id = "publications";
        title = "Publications";
      }
      {
        id = "blog";
        title = "Blog";
      }
    ];

    footerNavPages = [
      {
        id = "legal";
        title = "Legal";
      }
    ];
  };

  page_definitions = [
    (import_nixfm ./index.nix.html)
    (import ./publications.nix)
    (import_nixfm ./legal.nix.html)

    # This provides the blog overview page & all blog entries:
    (import ./blog.nix renderBlogDrafts)
  ];

  ensureUnique =
    desc: pred: list:
    (lib.foldl
      (
        { newlist, knownvals }:
        elem:
        if builtins.elem (pred elem) knownvals then
          abort "${desc} is not unique, non-unique value: ${builtins.toString (pred elem)}"
        else
          {
            newlist = newlist ++ [ elem ];
            knownvals = knownvals ++ [ (pred elem) ];
          }
      )
      {
        newlist = [ ];
        knownvals = [ ];
      }
      list
    ).newlist;

  rec_page_eval =
    self:
    (lib.listToAttrs (
      builtins.map (applied: lib.nameValuePair applied.meta.pageId applied) (
        ensureUnique "pageUrl" (applied: applied.meta.url) (
          ensureUnique "filePath" (applied: applied.meta.filePath) (
            ensureUnique "pageId" (applied: applied.meta.pageId) (
              lib.flatten (builtins.map (page_fn: page_fn (site_page_args // { pages = self; })) page_definitions)
            )
          )
        )
      )
    ));

  applied_pages = lib.fix rec_page_eval;

  # Fetch only the two files we serve, rather than the full Google Fonts archive.
  kalamBaseUrl = "https://raw.githubusercontent.com/google/fonts/5174b3333331c966c38f4355d50b03ca1c1df2f9/ofl/kalam";
  kalam = pkgs.fetchurl {
    url = "${kalamBaseUrl}/Kalam-Regular.ttf";
    hash = "sha256-V87LY9RggBk3GVQnSuHYw5d2TevVsZ1KM8HvpNySPAs=";
  };
  kalamLicense = pkgs.fetchurl {
    url = "${kalamBaseUrl}/OFL.txt";
    hash = "sha256-9i7zV9Ohw9J+3TWm4bo1DoqNE0mXl5ZO6t778LOxXR8=";
  };

  static_dir = ./static;

  output = symlinkJoin {
    name = "homepage";

    paths = [
      (stdenvNoCC.mkDerivation {
        name = "homepage-static";
        src = static_dir;
        installPhase = ''
          mkdir -p ./assets/font/

          # Primary Fira font face
          ln -s ${pkgs.fira}/share/fonts/opentype/FiraSans-Regular.otf ./assets/font/firasans-regular.otf
          ln -s ${pkgs.fira}/share/fonts/opentype/FiraSans-Bold.otf ./assets/font/firasans-bold.otf

          # Greeting font and its redistribution license, fetched with pinned hashes.
          ln -s ${kalam} ./assets/font/kalam-regular.ttf
          ln -s ${kalamLicense} ./assets/font/kalam-LICENSE.txt

          # Fallback DejaVu font face
          ln -s ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf ./assets/font/dejavusans-regular.ttf
          ln -s ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf ./assets/font/dejavusans-bold.ttf

          # Fontawesome & academicons logos
          ln -s "${pkgs.font-awesome_4}/share/fonts/opentype/FontAwesome.otf" \
            ./assets/font/fontawesome4.otf
          ln -s "${
            pkgs.fetchFromGitHub {
              owner = "jpswalsh";
              repo = "academicons";
              rev = "v1.9.4";
              sha256 = "sha256-mGHqOc0Q3cTXlziLmWETd4QrmF4++4RIbaJ/3yfAdVg=";
            }
          }/fonts/academicons.ttf" ./assets/font/academicons.ttf

          cp -rf . $out
        '';
      })
    ]
    ++ (lib.mapAttrsToList (
      _: page:
      let
        meta = page.meta;
        content = page.content;
      in
      writeTextFile {
        name = lib.last (lib.splitString "/" meta.filePath);
        text = content;
        destination = meta.filePath;
      }
    ) applied_pages);

    passthru = {
      pages = applied_pages;
    };
  };

  checkedOutput = stdenvNoCC.mkDerivation {
    name = "homepage-checked";

    # Depend on the various validators as nativeBuildInputs, which
    # ensures that they're built. They also operate on the final
    # output, which allows them to do relative path traversal in the
    # output derivation:
    nativeBuildInputs = builtins.map (page: page.validator "${output}") (
      lib.filter (page: page.validator != null) (builtins.attrValues applied_pages)
    );

    # Don't require an explicit source attribute
    dontUnpack = true;

    # Simply symlink to the unchecked output derivation
    installPhase = ''
      ln -s ${output} $out
      ls -lh $out
    '';

    # Avoid errors related to fixup attempting to fix permissions on
    # the output derivation:
    fixupPhase = "true";

    inherit (output) passthru;
  };

in
if doCheck then checkedOutput else output
