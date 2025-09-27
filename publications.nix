{
  lib,
  util,
  assetsPath,
  pages,
  ...
}@site_args:
let

  data = util.import_yaml ./publications.yml;

  publicationLink =
    key:
    if (builtins.hasAttr key data.publications) then
      "${pages.publications.meta.url}#${key}"
    else
      throw "Publicaton with key ${key} not defined!";

  fontIcons = {
    doi = [
      "academicons"
      "&#xe97e;"
    ];
    link = [
      "fontawesome4"
      "&#xf0c1;"
    ];
    pdf = [
      "fontawesome4"
      "&#xf1c1;"
    ];
    globe = [
      "fontawesome4"
      "&#xf0ac;"
    ];
  };

  typeLabel = {
    "paper" = "Paper";
    "poster" = "Poster";
    "techreport" = "Technical Report";
    "thesis" = "Thesis";
    "talk" = "Talk";
  };

  expandLinks =
    pub:
    (lib.optional (pub ? "doi") {
      fontIcon = fontIcons.doi;
      url = "https://doi.org/${pub.doi}";
      label = pub.doi;
    })
    ++ (lib.optional (pub ? "pdf") {
      fontIcon = fontIcons.pdf;
      url = pub.pdf;
      label = "PDF";
    })
    ++ (lib.optional (pub ? "slides_pdf") {
      fontIcon = fontIcons.pdf;
      url = pub.slides_pdf;
      label = "Slides (PDF)";
    })
    ++ (lib.optional (pub ? "webpage") {
      fontIcon = fontIcons.globe;
      url = pub.webpage;
      label = "Webpage";
    })
    ++ (pub.extraLinks or [ ]);

  htmlLinks =
    pub:
    lib.concatStringsSep ", " (
      builtins.map (
        link:
        ''<a href="${link.url}">${
          if link ? fontIcon then
            ''<span class="icon-${builtins.head link.fontIcon}">${builtins.head (builtins.tail link.fontIcon)} </span>''
          else if link ? imageIcon then
            ''<img class="link-icon" src="${builtins.head link.imageIcon}"${
              lib.optionalString (
                lib.length link.imageIcon > 1
              ) ''balt="${builtins.head (builtins.tail link.imageIcon)}"''
            }>''
          else
            ""
        }${link.label}</a>''
      ) (expandLinks pub)
    );

  htmlAuthorString =
    pub:
    lib.concatStringsSep ", " (
      builtins.map (
        authorAffiliation:
        let
          # An author can have multiple institutions over time, so we
          # specify authors of publications as "<author>@<affil>"
          splitAuthorAffiliation = lib.splitString "@" authorAffiliation;
          authorKey = builtins.head splitAuthorAffiliation;
          affiliationKey = builtins.head (builtins.tail splitAuthorAffiliation);

          # The author is uniquely identified by the "authorKey" and
          # can be looked up in the "authors" object.
          author = data.authors."${authorKey}";
          fullName = "${author.first} ${author.last}";

          # The author object has affiliations (a map from affiliation
          # key to attributes, or just "null"). If certain affiliation
          # fields are not overwritten, we take them from the
          # "institutions" object.
          affiliation =
            (data.institutions."${affiliationKey}" or { })
            // (
              if author.affiliations."${affiliationKey}" != null then
                author.affiliations."${affiliationKey}"
              else
                { }
            );

          authorSpan = ''<span title="${fullName}, ${affiliation.institution}">${fullName}</span>'';
        in
        if author ? "website" && authorKey != "schuermann_leon" then
          ''<a href="${author.website}">${authorSpan}</a>''
        else
          authorSpan
      ) pub.authors
    );

  paperPosterTemplate =
    pub:
    let
      venue = data.venues."${pub.venue}";
      dateFmt = util.expandDate pub.date;
    in
    ''
      <b>${pub.title}</b><br>
      <i>${htmlAuthorString pub}</i><br>
      ${if pub.unpublished or false then "To appear in" else "In"}
      ${venue.abbrev}: <i>${venue.name}</i>${
        if venue ? "remark" then ", ${venue.remark}" else ""
      }, ${dateFmt.B} ${dateFmt.Y}${
        lib.optionalString (pub.best_paper or false) ", <strong>Awarded Best Paper!</strong>"
      }<br>
      ${htmlLinks pub}
    '';

  techreportTemplate =
    pub:
    let
      dateFmt = util.expandDate pub.date;
    in
    ''
      <b>${pub.title}</b><br>
      <i>${htmlAuthorString pub}</i><br>
      ${pub.techreportPublisher}, Technical Report ${pub.techreportNumber}, ${dateFmt.B} ${dateFmt.Y}<br>
      ${htmlLinks pub}
    '';

  thesisTemplate =
    pub:
    let
      dateFmt = util.expandDate pub.date;
    in
    ''
      <b>${pub.title}</b><br>
      <i>${htmlAuthorString pub}</i><br>
      ${pub.thesisLabel}, ${pub.thesisInstitution}, ${dateFmt.B} ${dateFmt.Y}<br>
      ${htmlLinks pub}
    '';

  talkTemplate =
    pub:
    let
      venue = data.venues."${pub.venue}";
      dateFmt = util.expandDate pub.date;
    in
    ''
      <b>${pub.title}</b><br>
      <i>${htmlAuthorString pub}</i><br>
      At
      ${lib.optionalString (venue ? "abbrev") "${venue.abbrev}: "}
      <i>${venue.name}</i>${
        if venue ? "remark" then ", ${venue.remark}" else ""
      }, ${dateFmt.B} ${dateFmt.Y}<br>
      ${htmlLinks pub}
    '';

  entryTemplate =
    pub:
    ({
      "paper" = paperPosterTemplate;
      "poster" = paperPosterTemplate;
      "techreport" = techreportTemplate;
      "thesis" = thesisTemplate;
      "talk" = talkTemplate;
    })."${pub.type}"
      pub;

  pubList = pubFilter: addPubtypeAnnotation: generateAnchor: ''
    <ul>
      ${lib.concatStringsSep "\n" (
        builtins.map
          (
            pub:
            ''<li><p${lib.optionalString generateAnchor " id=\"${pub.name}\""}>${lib.optionalString addPubtypeAnnotation ''[${typeLabel."${pub.value.type}"}] ''}${entryTemplate pub.value}</p></li>''
          )
          (
            builtins.sort (a: b: a.value.date > b.value.date) (
              builtins.filter (pub: pubFilter pub.name pub.value) (
                lib.mapAttrsToList lib.nameValuePair data.publications
              )
            )
          )
      )}
    </ul>
  '';

in
[
  (util.import_nixfm ./page.nix.html (
    site_args
    // {
      # For main pages, just provide a simple lower-case name of the page as the
      # site ID
      pageId = "publications";
      pageUrl = "/publications.html";

      # content = "Something something I'm a well published researcher";
      content = ''
        <p>Switch to a <a href="${pages.publications_chronological.meta.url}">chronological view</a>.</p>

        <h2>Selected Publications</h2>
        ${pubList (_: p: (p.selected or false)) false false}

        <hr>

        <h2>Conference / Workshop Papers</h2>
        ${pubList (_: p: p.type == "paper") false true}

        <h2>Talks</h2>
        ${pubList (_: p: p.type == "talk") false true}

        <h2>Theses</h2>
        ${pubList (_: p: p.type == "thesis") false true}

        <h2>Reports, Posters, and Other Publications</h2>
        ${pubList (
          _: p:
          !(builtins.elem p.type [
            "thesis"
            "paper"
            "talk"
          ])
        ) false true}
      '';

      export = {
        inherit
          data
          publicationLink
          ;
      };
    }
  ))

  (util.import_nixfm ./page.nix.html (
    site_args
    // {
      pageId = "publications_chronological";
      pageUrl = "/publications_chronological.html";
      pageNavidMatches = [ "publications" ];
      canonicalPageId = "publications";

      # content = "Something something I'm a well published researcher";
      content = ''
        <p>Switch to a <a href="${pages.publications.meta.url}">categorical view</a>.</p>

        ${pubList (_: _: true) true true}
      '';
    }
  ))
]
