{ lib, util, assetsPath, pages, ... }@site_args: let

  publicationLink = key:
    if (builtins.hasAttr key pubs) then
      "${pages.publications.meta.url}#${key}"
    else
      throw "Publicaton with key ${key} not defined!";

  fontIcons = {
    link = [ "fontawesome4" "&#xf0c1;" ];
    pdf = [ "fontawesome4" "&#xf1c1;" ];
    doi = [ "academicons" "&#xe97e;" ];
  };

  typeLabel = {
    "paper" = "Paper";
    "poster" = "Poster";
    "techreport" = "Technical Report";
    "thesis" = "Thesis";
    "talk" = "Talk";
  };

  authors = {
    me = {
      first = "Leon";
      last = "Schuermann";

      affiliations = {
        princeton = {
          institution = "Princeton University";
          country = "USA";
        };

        uni_stuttgart = {
          institution = "University of Stuttgart";
          country = "Germany";
        };
      };
    };

    amit_levy = {
      first = "Amit";
      last = "Levy";

      affiliations.princeton = {
        institution = "Princeton University";
        country = "USA";
      };
    };

    arun_thomas = {
      first = "Arun";
      last = "Thomas";

      affiliations.zerorisc = {
        institution = "zeroRISC Inc.";
        country = "USA";
      };
    };

    frank_duerr = {
      first = "Frank";
      last = "Duerr";

      affiliations.uni_stuttgart = {
        institution = "University of Stuttgart";
        country = "Germany";
      };
    };

    jack_toubes = {
      first = "Jack";
      last = "Toubes";

      affiliations.princeton = {
        institution = "Princeton University";
        country = "USA";
      };
    };

    mae_milano = {
      first = "Mae";
      last = "Milano";

      affiliations.princeton = {
        institution = "Princeton University";
        country = "USA";
      };
    };

    tyler_potyondy = {
      first = "Tyler";
      last = "Potyondy";

      affiliations.ucsd = {
        institution = "University of California, San Diego";
        country = "USA";
      };
    };

  };

  venues = {
    "SOSP23" = {
      type = "conference";
      abbrev = "SOSP '23";
      name = "The 29th ACM Symposium on Operating Systems Principles";
      website = "https://sosp2023.mpi-sws.org/";
    };

    "KISV23" = {
      type = "workshop";
      abbrev = "KISV '23";
      name = "1st Workshop on Kernel Isolation, Safety and Verification";
      website = "https://kisv-workshop.github.io/";
      remark = "Co-located with SOSP '23";
    };

    "OSDI23" = {
      type = "conference";
      abbrev = "OSDI '23";
      name =
        "17th USENIX Symposium on Operating Systems Design and Implementation";
      website = "https://www.usenix.org/conference/osdi23";
    };

    "RustNL24" = {
      type = "conference";
      name = "RustNL 2024";
      website = "https://2024.rustnl.org/";
    };
  };

  pubs = {
    "rustnl2024-encapsulated-functions" = {
      date = "2024-05-07";
      type = "talk";
      venue = "RustNL24";

      title =
        "Safe Interactions with Foreign Languages through Encapsulated Functions";
      authors = [
        [ "me" "princeton" ]
        [ "jack_toubes" "princeton" ]
        [ "tyler_potyondy" "ucsd" ]
        [ "mae_milano" "princeton" ]
        [ "amit_levy" "princeton" ]
      ];

      slides_pdf = "/publications/2024_Schuermann_Encapsulated-Functions_RustNL24_Slides.pdf";
    };

    "sosp23-encapsulated-functions-poster" = {
      date = "2023-10-24";
      type = "poster";
      venue = "SOSP23";

      title =
        "Encapsulated Functions: Fortifying Rust's FFI in Embedded Systems";
      authors = [
        [ "me" "princeton" ]
        [ "arun_thomas" "zerorisc" ]
        [ "amit_levy" "princeton" ]
      ];

      pdf = "/publications/2023_Schuermann_Encapsulated-Functions_SOSP23-poster.pdf";
    };

    "kisv23-encapsulated-functions" = {
      date = "2023-10-23";
      type = "paper";
      venue = "KISV23";

      title =
        "Encapsulated Functions: Fortifying Rust's FFI in Embedded Systems";
      authors = [
        [ "me" "princeton" ]
        [ "arun_thomas" "zerorisc" ]
        [ "amit_levy" "princeton" ]
      ];

      doi = "10.1145/3625275.3625397";
    };

    "osdi23-helix-poster" = {
      date = "2023-07-10";
      type = "poster";
      venue = "OSDI23";

      title =
        "HELIX: Co-designing the Hardware, Software and Network Protocol "
        + "for Reliable High-Bandwidth Communication in Constrained Systems";
      authors = [
        [ "me" "princeton" ]
        [ "amit_levy" "princeton" ]
        [ "frank_duerr" "uni_stuttgart" ]
      ];

      pdf = "/publications/2023_Schuermann_HELIX_OSDI23-poster.pdf";
    };

    "2022-helix-master-thesis" = {
      date = "2022-04-20";
      type = "thesis";

      thesisLabel = "Master' Thesis";
      thesisInstitution =
        "University of Stuttgart, Institute of Parallel and Distributed Systems";

      title =
        "Design and Evaluation of System Concepts and Protocols for "
        + "Lossless Hardware-Assisted Streaming of Real-Time Measurement Data "
        + "over IP Networks";
      authors = [
        [ "me" "uni_stuttgart" ]
      ];

      doi = "10.18419/opus-12456";
    };

    "2021-ptp-time-sync-embedded-systems" = {
      date = "2021-12-05";
      type = "techreport";

      techreportPublisher =
        "University of Stuttgart, Institute of Parallel and Distributed Systems";
      techreportNumber = "TR-2021-02";

      title =
        "Implementation and Evaluation of Time Synchronization Mechanisms for "
        + "Generic Embedded Systems for Time Sensitive Networking (TSN)";
      authors = [
        [ "me" "uni_stuttgart" ]
        [ "frank_duerr" "uni_stuttgart" ]
      ];

      pdf = "/publications/2021_Schuermann_ptp-time-sync-embedded-systems.pdf";

      extraLinks = [{
        fontIcon = fontIcons.link;
        url = "http://www2.informatik.uni-stuttgart.de/cgi-bin/NCSTRL/NCSTRL_view.pl?id=TR-2021-02&mod=1&engl=1&inst=FAK";
        label = "Online Record";
      }];
    };
  };


  expandLinks = pub:
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
    ++ (pub.extraLinks or []);

  htmlLinks = pub:
    lib.concatStringsSep ", " (
      builtins.map (link:
        ''<a href="${link.url}">${
          if link ? fontIcon then
            ''<span class="icon-${builtins.head link.fontIcon}">${
              builtins.head (builtins.tail link.fontIcon)} </span>''
          else if link ? imageIcon then
            ''<img class="link-icon" src="${builtins.head link.imageIcon}"${
              lib.optionalString
                (lib.length link.imageIcon > 1)
                ''balt="${builtins.head (builtins.tail link.imageIcon)}"''
            }>''
          else
            ""
        }${link.label}</a>''
      ) (expandLinks pub)
    );

  htmlAuthorString = pub:
    lib.concatStringsSep ", " (
      builtins.map (a: let
        authorKey = builtins.head a;
        affiliationKey = builtins.head (builtins.tail a);
        author = authors."${authorKey}";
        affiliation = author.affiliations."${affiliationKey}";
        fullName = "${author.first} ${author.last}";
      in
        ''<span title="${fullName}, ${affiliation.institution}">${fullName}</span>''
      ) pub.authors);

  paperPosterTemplate = pub: let
    venue = venues."${pub.venue}";
    dateFmt = util.expandDate pub.date;
  in ''
    <b>${pub.title}</b><br>
    <i>${htmlAuthorString pub}</i><br>
    ${if pub.unpublished or false then "To appear in" else "In"}
    ${venue.abbrev}: <i>${venue.name}</i>${
      if venue ? "remark" then ", ${venue.remark}" else ""
    }, ${dateFmt.B} ${dateFmt.Y}<br>
    ${htmlLinks pub}
  '';

  techreportTemplate = pub: let
    dateFmt = util.expandDate pub.date;
  in ''
    <b>${pub.title}</b><br>
    <i>${htmlAuthorString pub}</i><br>
    ${pub.techreportPublisher}, Technical Report ${pub.techreportNumber}, ${dateFmt.B} ${dateFmt.Y}<br>
    ${htmlLinks pub}
  '';

  thesisTemplate = pub: let
    dateFmt = util.expandDate pub.date;
  in ''
    <b>${pub.title}</b><br>
    <i>${htmlAuthorString pub}</i><br>
    ${pub.thesisLabel}, ${pub.thesisInstitution}, ${dateFmt.B} ${dateFmt.Y}<br>
    ${htmlLinks pub}
  '';

  talkTemplate = pub: let
    venue = venues."${pub.venue}";
    dateFmt = util.expandDate pub.date;
  in ''
    <b>${pub.title}</b><br>
    <i>${htmlAuthorString pub}</i><br>
    At
    ${lib.optionalString (venue ? "abbrev") "${venue.abbrev}: "}
    <i>${venue.name}</i>${
      if venue ? "remark" then ", ${venue.remark}" else ""
    }, ${dateFmt.B} ${dateFmt.Y}<br>
    ${htmlLinks pub}
  '';

  entryTemplate = pub: ({
    "paper" = paperPosterTemplate;
    "poster" = paperPosterTemplate;
    "techreport" = techreportTemplate;
    "thesis" = thesisTemplate;
    "talk" = talkTemplate;
  })."${pub.type}" pub;

  pubList = typeFilter: typeAnnotation: ''
    <ul>
      ${lib.concatStringsSep "\n" (
        builtins.map (pub:
          ''<li><p id="${pub.name}">${
            lib.optionalString typeAnnotation ''[${typeLabel."${pub.value.type}"}] ''
          }${entryTemplate pub.value}</p></li>''
        ) (builtins.sort
          (a: b: a.value.date > b.value.date)
          (builtins.filter
            (pub: typeFilter pub.value.type)
            (lib.mapAttrsToList lib.nameValuePair pubs)
          )
        )
      )}
    </ul>
  '';

in [
  (util.import_nixfm ./page.nix.html (
    site_args // {
      # For main pages, just provide a simple lower-case name of the page as the
      # site ID
      pageId = "publications";
      pageUrl = "/publications.html";

      # content = "Something something I'm a well published researcher";
      content = ''
        <p>Switch to a <a href="${pages.publications_chronological.meta.url}">chronological view</a>.</p>

        <h2>Peer Reviewed</h2>
        ${pubList (type: type == "paper") false}

        <h2>Talks</h2>
        ${pubList (type: type == "talk") false}

        <h2>Theses</h2>
        ${pubList (type: type == "thesis") false}

        <h2>Reports, Posters and Other Publications</h2>
        ${pubList (type: !(builtins.elem type ["thesis" "paper" "talk"])) false}
      '';

      export = {
        inherit
          authors
          venues
          pubs
          publicationLink
        ;
      };
    }
  ))

  (util.import_nixfm ./page.nix.html (
    site_args // {
      pageId = "publications_chronological";
      pageUrl = "/publications_chronological.html";
      pageNavidMatches = [ "publications" ];
      canonicalPageId = "publications";

      # content = "Something something I'm a well published researcher";
      content = ''
        <p>Switch to a <a href="${pages.publications.meta.url}">categorical view</a>.</p>

        ${pubList (_: true) true}
      '';
    }
  ))
]
