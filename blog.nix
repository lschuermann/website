renderDrafts:
{
  pkgs,
  lib,
  util,
  pages,
  urlPrefix,
  ...
}@site_args:
let
  pageHeaderTitle = "Leon's Blog";

  # For JSON-LD structured data:
  authorUrls = {
    "Leon Schuermann" = "https://leon.schuermann.io/";
  };

  # All blog pages should match on all blog navigation entries:
  pageNavidMatches = pageId: pageId == "blog" || lib.hasPrefix "blog-" pageId;

  tagLinks =
    tags:
    lib.concatStringsSep " " (
      builtins.map (tag: ''
        <a href="${pages."blog-tag-${tag}".meta.url}">#${tag}</a>
      '') (lib.sort (a: b: lib.lessThan (lib.toLower a) (lib.toLower b)) tags)
    );

  orgBlogEntry =
    basedir: filename:
    let
      emacsPkg = pkgs.emacs-nox.pkgs.withPackages (
        epkgs: with epkgs; [
          org
          use-package
          htmlize
          org-contrib

          # Syntax highlighting packages
          nix-mode
          elixir-mode
          rust-mode
          llvm-mode
        ]
      );

      derivPrefix = "blog-${filename}";

      # Only depend on the actual source file (read once, and then
      # written back to the Nix store). If we depend on the actual
      # path in the file system, this causes all blog posts to be
      # rebuilt (expensive!).
      orgSource = builtins.readFile "${basedir}/${filename}";
      orgFile = pkgs.writeText derivPrefix orgSource;
      basename = lib.removeSuffix ".org" filename;

      # The frontmatter is a single Nix block; extracting it directly avoids
      # starting Emacs (and building its closure) during metadata evaluation.
      frontmatterParts = lib.splitString "#+BEGIN_SRC nix :tangle frontmatter.nix\n" orgSource;
      frontmatterNix =
        if builtins.length frontmatterParts != 2 then
          throw "Expected one frontmatter block in ${filename}"
        else
          builtins.toFile "${derivPrefix}-frontmatter.nix" (
            builtins.head (lib.splitString "#+END_SRC" (builtins.elemAt frontmatterParts 1))
          );

      frontmatter = import "${frontmatterNix}" {
        inherit
          orgSource
          lib
          pkgs
          util
          ;
      };

      orgModeHtmlExport =
        file: suffix:
        pkgs.runCommand "${derivPrefix}-${suffix}.html" { } ''
          cp "${file}" "./${filename}"
          ${emacsPkg}/bin/emacs -Q --batch --eval "
            (progn
              (require 'use-package)
              (use-package nix-mode)
              (use-package elixir-mode)
              (use-package rust-mode)
              (use-package llvm-mode)

              (custom-set-faces
               '(default                      ((t (:foreground \"black\" :background \"white\"))))
               '(font-lock-builtin-face       ((t (:foreground \"dark slate blue\"))))
               '(font-lock-comment-face       ((t (:bold t :foreground \"Firebrick\"))))
               '(font-lock-constant-face      ((t (:foreground \"dark cyan\"))))
               '(font-lock-function-name-face ((t (:bold t :foreground \"Blue1\"))))
               '(font-lock-keyword-face       ((t (:foreground \"Purple\"))))
               '(font-lock-string-face        ((t (:foreground \"VioletRed4\"))))
               '(font-lock-type-face          ((t (:foreground \"ForestGreen\"))))
               '(font-lock-variable-name-face ((t (:foreground \"sienna\" :bold t))))
               '(font-lock-warning-face       ((t (:foreground \"red\" :weight bold)))))


              (setq htmlize-use-rgb-map 'force)
              (use-package htmlize)
              (setq org-html-htmlize-font-prefix \"org-\")
              (setq org-html-htmlize-output-type 'inline-css)

              ; Static headline labels in articles
              (setq org-html-prefer-user-labels 't)

              (setq org-confirm-babel-evaluate nil)

              (dolist (file command-line-args-left)
                (with-current-buffer (find-file-noselect file)
                  (font-lock-fontify-buffer)
                  (org-babel-goto-named-src-block \"org_setup\")
                  (org-babel-execute-src-block)
                  (org-html-export-to-html nil nil nil 't))))
          " "./${filename}"
          cp "./$(basename "${filename}" .org).html" $out

          # Sanity check: we don't want to produce any elements that don't have a
          # stable HTML `id` property. This is a quite dirty hack -- I'll replace
          # when it breaks with false positives:
          if grep -E '^.*id="org[[:alnum:]]+".*$' "$out"; then
            echo "Post ${filename} generates elements with non-static org ids!" >&2
            exit 1
          fi
        '';

      nullOr = cond: val: if cond then val else null;

      abstract = nullOr ((frontmatter.abstractTag or null) != null) (
        builtins.readFile "${orgModeHtmlExport (pkgs.writeText "${derivPrefix}-abstract.org" ''
          #+SELECT_TAGS: ${frontmatter.abstractTag}
          ${lib.concatStringsSep "\n" (
            lib.filter (
              line: !(lib.hasPrefix "#+EXCLUDE_TAGS: " line) && !(lib.hasPrefix "#+SELECT_TAGS: ") line
            ) (pkgs.lib.splitString "\n" orgSource)
          )}
        '') "abstract"}"
      );

    in
    util.import_nixfm ./page.nix.html (
      site_args
      // rec {
        inherit pageNavidMatches pageHeaderTitle abstract;

        pageId = "blog-${basename}";
        filePath = "/blog/${basename}.html";
        pageTitle = frontmatter.title;

        # Import from derivation!
        content =
          let
            dateFmt = util.parseRFC3339Sec frontmatter.date;
          in
          ''
            <h1 class="first-heading">${frontmatter.title}</h1>
            <i>
              <span title="${util.formatRFC3339Sec dateFmt}">
                ${dateFmt.B} ${dateFmt.d}, ${dateFmt.Y}
              </span> &ndash; ${lib.concatStringsSep ", " frontmatter.authors} &ndash; ${tagLinks export.blogpost.tags}
            </i>

            ${builtins.readFile "${orgModeHtmlExport orgFile "body"}"}
          '';

        pageCss = ''
          main p {
            text-align: left;
          }

          div.org-src-container, pre.example {
            overflow: auto;
            border-radius: 3px;
            background-color: #eeeee6;
            font-size: .8em;
          }

          div.org-src-container {
            padding: 0px 15px 00px 15px;
          }

          pre.example {
            padding: 10px 15px 10px 15px;
          }

          @media all and (min-width: 400px) {
            div.org-src-container, pre.example {
              width: 90%;
              margin: auto;
            }
          }

          blockquote {
            border-left: 4px solid lightgray;
            padding-left: 10px;
          }

          div.org-src-container span.linenr {
            opacity: .6;
          }
        '';

        jsonLd = rec {
          "@context" = "https://schema.org";
          "@type" = "BlogPosting";
          "headline" = frontmatter.title;
          "datePublished" = util.formatRFC3339Sec (util.parseRFC3339Sec frontmatter.date);
          "dateModified" = util.formatRFC3339Sec (
            util.parseRFC3339Sec (frontmatter.dateUpdated or frontmatter.date)
          );
          "author" = builtins.map (
            author:
            {
              "@type" = "Person";
              "name" = author;
              "url" = authorUrls."${author}";
            }
            // (lib.optionalAttrs (authorUrls."${author}" != null) {
              "url" = authorUrls."${author}";
            })
          ) frontmatter.authors;
        };

        export = {
          blogpost = {
            inherit (frontmatter) title date authors;
            description = frontmatter.description or "";
            tags = frontmatter.tags or [ ];
            unpublished = frontmatter.unpublished or false;
            published = util.parseRFC3339Sec frontmatter.date;
            updated = util.parseRFC3339Sec (frontmatter.dateUpdated or frontmatter.date);
            content = builtins.readFile "${orgModeHtmlExport orgFile "body"}";
          };
        };
      }
    );

  # Unfortunately, we cannot "discover" blogpost pages using a function like
  # this. This does not work, given that we're also generating pages in the same
  # fixpoint expression. For this to work, we'd probably need to fix blog posts
  # in another set of pages, which is guaranteed not to be influenced by the set
  # of tag pages we generate...
  #
  # blogPages =
  #   lib.filter
  #     (page: page.export ? "blogpost")
  #     (builtins.attrValues pages)

  # For now, simply generate the pages here centrally, in a single file, not
  # recursively dependent on `pages`:
  blogPages = (
    builtins.map (orgBlogEntry ./blog)
      # The [^\.] ignores files starting with a dot, such as auto-save
      # files created by emacs. This spares us of a bunch of rebuilds!
      (
        lib.filter (filename: renderDrafts || !(lib.hasPrefix "0000_draft_" filename)) (
          lib.filter (filename: (builtins.match "^[^\.].*\.org$" filename) != null) (
            builtins.attrNames (builtins.readDir ./blog)
          )
        )
      )
  );

  # External articles for the homepage Writing carousel.
  externalWriting = [
    {
      title = "Memory Safety Is Merely Table Stakes";
      date = "2025-06";
      url = "https://www.usenix.org/publications/loginonline/" + "memory-safety-merely-table-stakes";
      source = "USENIX ;login:";
      description = ''
        An introduction to Omniglot’s motivation and approach to safely using
        untrusted foreign libraries from Rust.
      '';
    }
  ];

  # Export published writing for the homepage, newest first.
  writing = lib.sort (a: b: a.date > b.date) (
    externalWriting
    ++ builtins.map (page: {
      inherit (page.export.blogpost) title;
      date = builtins.substring 0 10 page.export.blogpost.date;
      url = page.meta.url;
      source = "Blog";
      description = page.export.blogpost.description;
    }) (lib.filter (page: !page.export.blogpost.unpublished) blogPages)
  );

  writingList = entries: ''
    <ul class="writing-list">
      ${lib.concatMapStringsSep "\n" (entry: ''
        <li>
          <h3>
            <a href="${lib.escapeXML entry.url}">
              ${lib.escapeXML entry.title}
            </a>
          </h3>
          <p class="writing-meta">
            <time datetime="${entry.date}">${entry.date}</time>
            · ${lib.escapeXML entry.source}
          </p>
          ${lib.optionalString (entry.description != "") ''
            <p>${lib.escapeXML entry.description}</p>
          ''}
        </li>
      '') entries}
    </ul>
  '';

  postListPages = pages: ''
    ${lib.concatStringsSep "\n" (
      builtins.map (
        blogpostPage:
        let
          meta = blogpostPage.meta;
          blogpost = blogpostPage.export.blogpost;
          dateFmt = util.parseRFC3339Sec blogpost.date;
        in
        ''
          <a class="post-entry" href="${meta.url}">
            <span class="post-date" title="${util.formatRFC3339Sec dateFmt}">
              ${dateFmt.b} ${dateFmt.d}, <br class="post-date-linebreak">${dateFmt.Y}
            </span>
          </a>
          <article class="post-preview">
            <a class="post-entry" href="${meta.url}"><h2>${blogpost.title}</h2></a>
            ${lib.optionalString (meta.abstract != null) ''
              ${meta.abstract}
              <i><a href="${meta.url}">Read more...</a></i>
            ''}
          </article>
        ''
      ) (builtins.sort (a: b: a.export.blogpost.date > b.export.blogpost.date) pages)
    )}
  '';

  postListMaybe =
    postFilter:
    let
      # Filter out unpublished pages by default.
      filtered = lib.filter (page: !(page.export.blogpost.unpublished) && (postFilter page)) blogPages;
    in
    if builtins.length filtered == 0 then "Nothing here yet... :/" else postListPages filtered;

  postOverviewPage =
    {
      pageId,
      filePath,
      header,
      postFilter,
      canonicalPageId ? null,
    }:
    util.import_nixfm ./page.nix.html (
      site_args
      // {
        pageId = pageId;
        filePath = filePath;
        canonicalPageId = canonicalPageId;

        inherit pageNavidMatches pageHeaderTitle;

        # The homepage consumes this data.
        export = lib.optionalAttrs (pageId == "blog") {
          inherit writing writingList;
        };

        content = ''
          ${header}
          ${postListMaybe postFilter}
        '';

        pageCss = ''
          h2 {
            margin-top: 0px;
            font-size: 1.5em;
          }

          a.post-entry {
            text-decoration: none;
          }

          span.post-date {
            color: #707070;
          }

          article.post-preview p {
            text-align: left;
          }

          @media only screen and (min-width: 600px) {
            span.post-date {
              float: left;
              clear: both;
              font-size: 1.5em;
              color: #707070;
            }

            article.post-preview {
              margin: 0 0 4.5em 100px;
            }
          }

          @media not screen and (min-width: 600px) {
            span.post-date {
              font-size: small;
            }

            article.post-preview h2 {
              margin-top: 0em;
            }

            br.post-date-linebreak {
              display: none;
            }
          }
        '';
      }
    );

  tagList = lib.zipAttrs (
    lib.flatten (
      builtins.map (page: builtins.map (tag: { "${tag}" = page; }) (page.export.blogpost.tags)) blogPages
    )
  );

  publishedTagList = lib.zipAttrs (
    lib.flatten (
      builtins.map (page: builtins.map (tag: { "${tag}" = page; }) (page.export.blogpost.tags)) (
        lib.filter (page: !page.export.blogpost.unpublished) blogPages
      )
    )
  );

in
blogPages
++ (builtins.map (
  tag:
  postOverviewPage {
    pageId = "blog-tag-${tag}";
    filePath = "/blog/tag/${tag}.html";
    header = ''<h1 class="first-heading">Blog &ndash; #${tag}</h1>'';
    postFilter = page: builtins.elem tag page.export.blogpost.tags;
    canonicalPageId = "blog";
  }
) (builtins.attrNames tagList))
++ [
  (postOverviewPage {
    pageId = "blog";
    filePath = "/blog.html";
    header = ''
      <h1 class="first-heading">Blog</h1>
      <p>          <a href="${pages.blog-atom.meta.url}">Atom feed</a>
        – Tags: ${tagLinks (builtins.attrNames publishedTagList)}
      </p>
    '';
    postFilter = (_: true);
  })
  {
    export = null;

    meta = rec {
      pageTitle = "Blog Atom feed";
      pageId = "blog-atom";
      filePath = "/blog/feed.xml";
      abstract = null;
      url = urlPrefix + filePath;
    };

    content =
      let
        # Last format update: add <content> with CDATA to Atom feed XML
        feedFormatUpdated = util.parseRFC3339Sec "2023-11-16 22:01:22-05:00";

        postsXml = pkgs.writeText "posts.xml" (
          builtins.toXML {
            title = "Leon's Blog";
            feedUrl = "${urlPrefix}/blog/feed.xml";
            alternateUrl = "${urlPrefix}/";

            # Set updated to either the latest blog post update
            # timestamp, or the timestamp of when the feed format was
            # last changed, which ever is later.
            updated =
              let
                blogPagesUpdated = builtins.map (page: page.export.blogpost.updated) blogPages;
                sorted = lib.sort (a: b: a.s > b.s) (blogPagesUpdated ++ [ feedFormatUpdated ]);
              in
              util.formatRFC3339Sec (builtins.head sorted);

            posts =
              builtins.map
                (page: {
                  inherit (page.export.blogpost) title authors;
                  url = page.meta.url;
                  id = page.meta.pageId;
                  published = util.formatRFC3339Sec page.export.blogpost.published;
                  abstract = page.meta.abstract;
                  content = page.export.blogpost.content;
                })
                (
                  lib.filter (page: !page.export.blogpost.unpublished) (
                    lib.sort (a: b: a.export.blogpost.updated.s > b.export.blogpost.updated.s) blogPages
                  )
                );
          }
        );

        postsStylesheet = pkgs.writeText "atom.xsl" (builtins.readFile ./atom.xsl);

        applied = pkgs.runCommand "feed.xml" { } ''
          cat "${postsXml}" | ${pkgs.libxslt}/bin/xsltproc ${postsStylesheet} - > $out
        '';
      in
      builtins.readFile "${applied}";

    validator = null;
  }
]
