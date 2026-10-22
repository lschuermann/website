{
  lib,
  pkgs,
  util,
  assetsPath,
  pages,
  urlPrefix,
  ...
}@site_args:
let

  data = util.import_yaml ./publications.yml;

  publicationLink =
    key:
    if (builtins.hasAttr key data.own_publications) then
      "${pages.publications.meta.url}#${key}"
    else if (builtins.hasAttr key data.acknowledged_contributions) then
      "${pages.publications.meta.url}#${key}"
    else
      throw "Publicaton with key ${key} not defined!";

  fontIcons = {
    ieee = [
      "academicons"
      "&#xe929;"
    ];
    acmdl = [
      "academicons"
      "&#xe96a;"
    ];
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
    (lib.optional (pub ? "doi") (
      {
        acmdl = {
          fontIcon = fontIcons.acmdl;
          label = "ACM DL";
        };
        ieee = {
          fontIcon = fontIcons.ieee;
          label = "IEEE Xplore";
        };
      }
      .${pub.doi_repository or ""} or {
        fontIcon = fontIcons.doi;
        label = "DOI";
      }
      // {
        url = "https://doi.org/${pub.doi}";
      }
    ))
    ++ (lib.optional (pub ? "pdf") {
      fontIcon = fontIcons.pdf;
      url = pub.pdf;
      label = "PDF";
    })
    ++ (lib.optional (pub ? "slides_pdf") {
      fontIcon = fontIcons.pdf;
      url = pub.slides_pdf;
      label = "Slides";
    })
    ++ (lib.optional (pub ? "webpage") {
      fontIcon = fontIcons.globe;
      url = pub.webpage;
      label = "Website";
    })
    ++ (pub.extraLinks or [ ]);

  htmlLinks =
    pub:
    lib.concatStringsSep "\n" (
      builtins.map (
        link:
        ''<a href="${link.url}">${
          if link ? fontIcon then
            ''<span aria-hidden="true" class="icon-${builtins.head link.fontIcon}">${builtins.head (builtins.tail link.fontIcon)} </span>''
          else if link ? imageIcon then
            ''<img class="link-icon" src="${builtins.head link.imageIcon}"${
              lib.optionalString (
                lib.length link.imageIcon > 1
              ) ''alt="${builtins.head (builtins.tail link.imageIcon)}"''
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

          authorSpan = ''<span title="${fullName}${
            lib.optionalString (author ? "native_lang_name") " (${author.native_lang_name})"
          }, ${affiliation.institution}">${fullName}</span>'';
        in
        if author ? "website" && authorKey != "schuermann_leon" then
          ''<a href="${author.website}">${authorSpan}</a>''
        else if authorKey == "schuermann_leon" then
          "<strong>${authorSpan}</strong>"
        else
          authorSpan
      ) pub.authors
    );

  award =
    pub:
    lib.optionalString (pub.best_paper or false)
      ''<span class="publication-award"><span class="icon-fontawesome4 publication-trophy" aria-hidden="true">&#xf091;</span> Best Paper</span>'';

  typePrefix =
    pub: showType:
    lib.optionalString showType ''<span class="publication-type">${typeLabel.${pub.type}} · </span>'';

  venueTemplate =
    pub: showType:
    let
      venue = data.venues."${pub.venue}";
    in
    ''
      <p class="publication-venue">
        ${typePrefix pub showType}${lib.optionalString (pub.unpublished or false) "To appear · "}
        <span class="venue-short">${venue.abbrev or venue.name}</span>
        <span class="venue-full">${venue.name}${
          lib.optionalString (venue ? remark) ", ${venue.remark}"
        }</span>
      </p>
    '';

  metadata =
    pub: showType:
    if
      builtins.elem pub.type [
        "paper"
        "poster"
        "talk"
      ]
    then
      venueTemplate pub showType
    else if pub.type == "techreport" then
      "<p>${typePrefix pub showType}${pub.techreportPublisher}, Technical Report ${pub.techreportNumber}</p>"
    else
      "<p>${typePrefix pub showType}${pub.thesisLabel}, ${pub.thesisInstitution}</p>";

  entryTemplate =
    pub: showType:
    let
      date = util.expandDate pub.date;
    in
    ''
      <div class="publication-entry">
        <time class="publication-date" datetime="${pub.date}">${date.b}<br class="publication-date-break"> ${date.Y}</time>
        <div class="publication-body">
          <h3 class="publication-title">${pub.title}</h3>
          <p class="publication-authors">${htmlAuthorString pub}</p>
          <div class="publication-meta">${metadata pub showType}${award pub}</div>
        </div>
        <div class="publication-links">${htmlLinks pub}</div>
      </div>
    '';

  sortedPublications =
    publicationsData: pubFilter:
    builtins.sort (a: b: a.value.date > b.value.date) (
      builtins.filter (pub: pubFilter pub.name pub.value) (
        lib.mapAttrsToList lib.nameValuePair publicationsData
      )
    );

  selectedPublications = ''
    <ul class="publication-highlights">
      ${lib.concatMapStringsSep "\n"
        (pub: ''
          <li>
            <a href="#${pub.name}">
              <span class="highlight-title">${pub.value.title} <span aria-hidden="true">↘</span></span>
              <span class="publication-meta">
                <span>${data.venues.${pub.value.venue}.abbrev}</span>${award pub.value}
              </span>
            </a>
          </li>
        '')
        (
          map (id: {
            name = id;
            value = data.own_publications.${id} or (throw "Unknown selected publication ID: ${id}");
          }) data.selected_publications
        )
      }
    </ul>
  '';

  sourceLink = ''<p class="publication-source"><a href="${pages.publications_yaml_html.meta.url}">Publication data source</a></p>'';

  publicationScript = ''
    <script>
      (() => {
        const selectedEntry = () => document.querySelector('.publication-list > li:target');
        document.addEventListener('click', (event) => {
          const entry = selectedEntry();
          if (!entry) return;
          const link = event.target.closest('a[href]');
          if (link) {
            const url = new URL(link.href, location.href);
            if (url.origin === location.origin && url.pathname === location.pathname
                && url.search === location.search && url.hash === location.hash) {
              entry.classList.remove('highlight-dismissed');
              return;
            }
          }
          if (!entry.contains(event.target)) entry.classList.add('highlight-dismissed');
        });
        window.addEventListener('hashchange', () => {
          document.querySelectorAll('.highlight-dismissed').forEach((entry) => {
            entry.classList.remove('highlight-dismissed');
          });
        });
      })();
    </script>
  '';

  publicationCss = ''
    .publication-views, .publication-index {
      display: flex;
      flex-wrap: wrap;
      align-items: baseline;
      gap: .4rem 1.1rem;
      font-size: .85rem;
    }

    .publication-heading {
      display: flex;
      flex-wrap: wrap;
      align-items: baseline;
      justify-content: space-between;
      gap: .4rem 1.2rem;
      margin-bottom: .7rem;
    }

    .publication-heading h1 {
      margin: 0;
    }

    .publication-views {
      margin: 0;
    }

    main > h2 {
      margin: 1.25rem 0 .65rem;
      font-size: 1.3rem;
    }

    .publication-views [aria-current] {
      color: var(--ink);
      border-bottom: 2px solid var(--green);
    }

    .publication-index {
      padding: .45rem 0;
    }

    .publication-index > span, .publication-source {
      color: var(--muted);
    }

    .publication-list, .publication-highlights {
      list-style: none;
      padding: 0;
      margin: 0;
    }

    main > .publication-list > li {
      padding: .8rem 0;
      margin: 0;
      border-bottom: 1px solid #d7dbd1;
      break-inside: avoid;
    }

    .publication-list > li:first-child {
      padding-top: .25rem;
    }

    .publication-list > li:last-child {
      border-bottom: 0;
    }

    .publication-title {
      font-size: 1.05rem;
      font-weight: 600;
      line-height: 1.45;
      text-wrap: auto;
      margin: 0 0 .2rem;
    }

    .publication-authors {
      font-size: .88rem;
      margin: 0 0 .2rem;
    }

    .publication-authors a {
      color: inherit;
      text-decoration: none;
    }

    .publication-authors a:hover {
      color: var(--green);
      text-decoration: underline;
    }

    .publication-authors strong {
      font-weight: 600;
    }

    .publication-meta {
      display: flex;
      flex-wrap: wrap;
      align-items: baseline;
      gap: .35rem .8rem;
      color: var(--muted);
      font-size: .8rem;
    }

    .publication-meta p {
      margin: 0;
    }

    .publication-venue {
      min-width: 0;
    }

    .venue-full {
      display: none;
    }

    .publication-list > li:hover .venue-short,
    .publication-list > li:target:not(.highlight-dismissed) .venue-short {
      display: none;
    }

    .publication-list > li:hover .venue-full,
    .publication-list > li:target:not(.highlight-dismissed) .venue-full {
      display: inline;
    }

    .publication-entry {
      display: grid;
      gap: .5rem 1.5rem;
      align-items: stretch;
      grid-template-columns: 3rem minmax(0, 1fr) 8rem;
    }

    .publication-date {
      color: #707070;
      font-size: .95rem;
      line-height: 1.45;
      text-align: right;
      padding-top: .2rem;
    }

    .publication-body {
      min-width: 0;
    }

    .publication-trophy {
      color: #b8860b;
      font-size: .95em;
    }

    .publication-award {
      color: var(--muted);
      font-weight: 600;
      white-space: nowrap;
    }

    .publication-links {
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      gap: .2rem;
      font-size: .95rem;
      border-left: 1px solid #d7dbd1;
      padding-left: 1rem;
    }

    .publication-links a {
      display: inline-block;
      padding: .2rem 0;
    }

    .publication-highlights {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: .65rem;
    }

    main > .publication-highlights > li {
      padding: 0;
      margin: 0;
      min-width: 0;
    }

    .publication-highlights > li > a {
      display: flex;
      flex-direction: column;
      height: 100%;
      padding: .7rem .85rem;
      border: 1px solid #e4e4e4;
      border-radius: 5px;
      background: #f8f8f8;
      text-decoration: none;
      font-size: .9rem;
      line-height: 1.4;
    }

    .highlight-title {
      font-weight: 600;
      text-decoration: underline;
      text-underline-offset: .2em;
    }

    .publication-highlights > li > a:hover {
      background: #f1f1f1;
      border-color: #ccc;
    }

    .publication-highlights .publication-meta {
      margin-top: auto;
      padding-top: .35rem;
    }

    @media (max-width: 550px) {
      .publication-highlights {
        grid-template-columns: minmax(0, 1fr);
      }

      .publication-entry {
        grid-template-columns: minmax(0, 1fr);
        row-gap: .35rem;
      }

      .publication-date {
        text-align: left;
        padding-top: 0;
      }

      .publication-date-break {
        display: none;
      }

      .publication-links {
        grid-column: 1;
        flex-direction: row;
        flex-wrap: wrap;
        gap: .3rem 1rem;
        border-left: 0;
        padding-left: 0;
      }
    }

    .publication-source {
      margin-top: 2rem;
      font-size: .8rem;
    }

    .publication-list > li:hover,
    .publication-list > li:target:not(.highlight-dismissed) {
      background: #f2f2f2;
      border-radius: 4px;
      box-shadow: 6px 0 #f2f2f2, -6px 0 #f2f2f2;
    }

    @media print {
      .publication-views, .publication-index, .publication-source {
        display: none;
      }

      .publication-list .venue-short {
        display: none !important;
      }

      .publication-list .venue-full {
        display: inline !important;
      }
    }
  '';

  pubList = publicationsData: pubFilter: addPubtypeAnnotation: generateAnchor: ''
    <ul class="publication-list">
      ${lib.concatStringsSep "\n" (
        builtins.map (
          pub:
          "<li${lib.optionalString generateAnchor " id=\"${pub.name}\""}>${entryTemplate pub.value addPubtypeAnnotation}</li>"
        ) (sortedPublications publicationsData pubFilter)
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
      pageCss = publicationCss;
      footerContent = publicationScript;
      pageId = "publications";
      pageTitle = "Publications";
      pageUrl = "/publications.html";

      content = ''
        <div class="publication-heading">
        <h1 class="first-heading">Publications</h1>
        <nav class="publication-views" aria-label="Publication view">
          <span aria-current="page">By category</span>
          <a href="${pages.publications_chronological.meta.url}">By date</a>
        </nav>
        </div>
        <nav class="publication-index" aria-label="Jump to category">
          <span>Jump to category:</span>
          <a href="#selected">Selected</a><a href="#papers">Papers</a>
          <a href="#talks">Talks</a><a href="#theses">Theses</a><a href="#other">Other</a>
        </nav>

        <h2 id="selected">Selected Publications</h2>
        ${selectedPublications}

        <h2 id="papers">Conference / Workshop Papers</h2>
        ${pubList data.own_publications (_: p: p.type == "paper") false true}

        <h2 id="talks">Talks</h2>
        ${pubList data.own_publications (_: p: p.type == "talk") false true}

        <h2 id="theses">Theses</h2>
        ${pubList data.own_publications (_: p: p.type == "thesis") false true}

        <h2 id="other">Reports, Posters, and Other Publications</h2>
        ${pubList data.own_publications (
          _: p:
          !(builtins.elem p.type [
            "thesis"
            "paper"
            "talk"
          ])
        ) false true}
        ${sourceLink}
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
      pageCss = publicationCss;
      footerContent = publicationScript;
      pageTitle = "Publications";
      pageId = "publications_chronological";
      pageUrl = "/publications_chronological.html";
      pageNavidMatches = [ "publications" ];
      canonicalPageId = "publications";

      content = ''
        <div class="publication-heading">
        <h1 class="first-heading">Publications</h1>
        <nav class="publication-views" aria-label="Publication view">
          <a href="${pages.publications.meta.url}">By category</a>
          <span aria-current="page">By date</span>
        </nav>
        </div>

        ${pubList data.own_publications (_: _: true) true true}
        ${sourceLink}
      '';
    }
  ))

  (util.import_nixfm ./page.nix.html (
    site_args
    // {
      pageCss = publicationCss;
      footerContent = publicationScript;
      pageId = "acknowledged_contributions";
      pageUrl = "/acknowledged_contributions.html";

      content = ''
        <h1 class="first-heading">Acknowledgments in Publications</h1>
        <p>Below is a list of papers I had the honor of contributing to one way or another:</p>

        ${pubList data.acknowledged_contributions (_: _: true) true true}
      '';
    }
  ))

  {
    meta = rec {
      pageId = "publications_yaml";
      filePath = "/publications.yaml";
      url = urlPrefix + filePath;
    };

    content = builtins.readFile ./publications.yml;

    validator = null;
  }

  rec {
    meta = {
      pageId = "publications_yaml_html";
      filePath = "/publications.yaml.html";
      url = urlPrefix + meta.filePath;
    };

    content = builtins.readFile (
      pkgs.runCommand "publications.yaml.html" { } ''
        ${pkgs.chroma}/bin/chroma --html --html-lines --html-linkable-lines ${./publications.yml} \
          | sed '/<html>/a <meta charset="utf-8">' >$out
      ''
    );

    # Unfortunately, the chroma output is pretty far from
    # validation. Therefore, we don't validate the HTML conformity of
    # this page:
    #
    # validator = util.htmlValidator pkgs meta.pageId meta.filePath;
    validator = null;
  }
]
