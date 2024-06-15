pkgs:

let
  parse_nixfm = file_ish: let
    contents = builtins.readFile file_ish;

    # Split file line by line, folding into an attribute set of
    # different "parts". A nixfm file must start with a part initator
    # (---$part) line.
    parts = pkgs.lib.foldl ({ parts, currentPart }: line: let
      partInitMatch = builtins.match "^---([a-zA-Z0-9_]+)$" line;
    in
      if partInitMatch != null then {
        parts = parts // { "${builtins.head partInitMatch}" = null; };
        currentPart = "${builtins.head partInitMatch}";
      } else if currentPart != null then {
        inherit currentPart;
        parts = parts // {
          "${currentPart}" =
            if parts."${currentPart}" == null then
              line
            else
              parts."${currentPart}" + "\n" + line;
        };
      } else (
        throw "Cannot parse nixfm file with content before part initiator!"
      )
    ) { parts = {}; currentPart = null; } (pkgs.lib.splitString "\n" contents);
  in
    parts.parts // {
      source_path = builtins.toString file_ish;
    };

  import_nixfm = file_ish: let
    parsed = parse_nixfm file_ish;
    nixDeriv = pkgs.writeText "import_nixfm_deriv.nix" parsed.nix;
  in
    import nixDeriv parsed;

  template = tmpl: ctx: let
    templateNixDeriv = pkgs.writeText "template_deriv.nix" ''
      ctx:
      ''\'''\'
      ${tmpl}
      ''\'''\'
    '';
  in
    import templateNixDeriv ctx;

  lineAttrTransform = transform: attr: prefix: line:
    if pkgs.lib.hasPrefix (pkgs.lib.toLower prefix) (pkgs.lib.toLower line) then
      {
        "${attr}" = transform (
          builtins.substring
            (builtins.stringLength prefix)
            ((builtins.stringLength line) - (builtins.stringLength prefix))
            line);
      }
    else
      {};

  lineAttr = lineAttrTransform (a: a);

  orgMeta = orgSource: (
    # First matching attribute found has precedence! Also, stop searching when
    # hitting a section marker.
    pkgs.lib.foldl ({ attrs, stop }: line:
      if stop then
        { inherit attrs stop; }
      else if pkgs.lib.hasPrefix "*" line then
        { inherit attrs; stop = true; }
      else
        {
          stop = false;
          attrs =
            (lineAttr "title" "#+TITLE: " line)
            // (lineAttr "date" "#+DATE: " line)
            // (lineAttrTransform (author: [author]) "authors" "#+AUTHOR: " line)
            // attrs;
        }
    ) { attrs = {}; stop = false; } (pkgs.lib.splitString "\n" orgSource)
  ).attrs;

  expandDate = datestr:
    parseRFC3339Sec "${datestr} 00:00:00-00:00";

  parseRFC3339Sec = datestr: let
    matchedRes = builtins.match (
      "^([0-9][0-9][0-9][0-9])-([0-9][0-9])-([0-9][0-9])"
      + "( |T)([0-9][0-9]):([0-9][0-9]):([0-9][0-9])"
      + "(\\+|-)([0-9][0-9]):([0-9][0-9])$") datestr;

    matched =
      if matchedRes == null then
        abort "Failed to parse RFC3339 second-formatted ${datestr}"
      else matchedRes;

    lib = pkgs.lib;

    # How many days are in a given month, useful for calculating UNIX
    # timestamp:
    monthDaysLookup = leapYear: {
      _01 = 31;
      _02 = if leapYear then 29 else 28;
      _03 = 31;
      _04 = 30;
      _05 = 31;
      _06 = 30;
      _07 = 31;
      _08 = 31;
      _09 = 30;
      _10 = 31;
      _11 = 30;
      _31 = 31;
    };

    daysUptoMonth = leapYear: let
      mdl = monthDaysLookup leapYear;
    in rec {
      _01 = 0;
      _02 = _01 + mdl._01;
      _03 = _02 + mdl._02;
      _04 = _03 + mdl._03;
      _05 = _04 + mdl._04;
      _06 = _05 + mdl._05;
      _07 = _06 + mdl._06;
      _08 = _07 + mdl._07;
      _09 = _08 + mdl._08;
      _10 = _09 + mdl._09;
      _11 = _10 + mdl._10;
      _12 = _11 + mdl._11;
    };

    isLeapYear = year: (lib.mod year 4) == 0;

    # fromYear: inclusive, toYear: exclusive
    leapYearCorrectionDays = fromYear: toYear: let
      yearSpan = toYear - fromYear;
      yearsToFirstLeapYear =
        lib.mod (4 - (lib.mod fromYear 4)) 4;
      leapYearConsiderationYears =
        lib.max 0 (yearSpan - yearsToFirstLeapYear);
    in
      (leapYearConsiderationYears / 4)
      + (lib.min 1 (lib.mod leapYearConsiderationYears 4));

    stripLeadingZeroes = str: let
      strippedCharList =
        lib.foldl (acc: char:
          if char != "0" || acc != [] then
            acc ++ [char]
          else
            acc
        ) [] (
          lib.filter
            (char: char != "")
            (lib.splitString "" str)
        );
    in
      if strippedCharList == [] then
        "0"
      else
        lib.concatStringsSep "" strippedCharList;

    toInt = str: lib.toIntBase10 (stripLeadingZeroes str);

  in rec {
    # https://strftime.net/
    Y = builtins.elemAt matched 0;
    m = builtins.elemAt matched 1;
    d = builtins.elemAt matched 2;
    k = builtins.elemAt matched 4;
    M = builtins.elemAt matched 5;
    S = builtins.elemAt matched 6;

    # Timezone offset (we provide some additional decompositions
    # prefixed by "z" as they are useful for converting to other
    # formats).
    zPlusMinus = builtins.elemAt matched 7;
    zMinus = if zPlusMinus == "-" then "-" else "";
    zHour = builtins.elemAt matched 8;
    zMinute = builtins.elemAt matched 9;
    zOffsetSec =
      ((toInt "${zMinus}${stripLeadingZeroes zHour}") * 3600)
      + ((toInt "${zMinus}${stripLeadingZeroes zMinute}") * 60);
    z = "${zPlusMinus}${zHour}${zMinute}";
    zColon = "${zPlusMinus}${zHour}:${zMinute}";

    # Unix timestamp
    sNoTzCorrection =
      if toInt Y < 1970 then
        abort "No Unix timestamp of ${datestr} (before 1970)"
      else
        (((toInt Y) - 1970) * 60 * 60 * 24 * 365)
        + ((leapYearCorrectionDays 1970 (toInt Y)) * 60 * 60 * 24)
        + ((daysUptoMonth (isLeapYear (toInt Y)))."_${m}" * 60 * 60 * 24)
        + (((toInt d) - 1) * 60 * 60 * 24)
        + ((toInt k) * 60 * 60)
        + ((toInt M) * 60)
        + (toInt S);
    s = sNoTzCorrection + (zOffsetSec * -1);
    sNoTzCorrectionDays = sNoTzCorrection / (60 * 60 * 24);

    # 1970-01-01 was a Thursday. We add 4 to have Sunday be our base:
    w = lib.mod (sNoTzCorrectionDays + 4) 7;
    u = if w == 0 then 7 else w;
    A = {
      "0" = "Sunday";
      "1" = "Monday";
      "2" = "Tuesday";
      "3" = "Wednesday";
      "4" = "Thursday";
      "5" = "Friday";
      "6" = "Saturday";
    }."${builtins.toString w}";
    a = builtins.substring 0 3 A;

    B = {
      "01" = "January";
      "02" = "February";
      "03" = "March";
      "04" = "April";
      "05" = "May";
      "06" = "June";
      "07" = "July";
      "08" = "August";
      "09" = "September";
      "10" = "October";
      "11" = "November";
      "12" = "December";
    }."${m}";
    b = builtins.substring 0 3 B;
  };

  formatRFC822 = p: with p;
    "${a}, ${d} ${b} ${Y} ${k}:${M}:${S} ${z}";

  formatRFC3339Sec = p: with p;
    "${Y}-${m}-${d}T${k}:${M}:${S}${zColon}";

in {
  inherit
    parse_nixfm
    import_nixfm
    template
    orgMeta
    expandDate
    parseRFC3339Sec
    formatRFC822
    formatRFC3339Sec
  ;
}
