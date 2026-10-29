{ libnet, ... }:
let
  # Every namespace with a parsing suite, so a new one is covered too.
  namespaces = builtins.filter (name: builtins.isAttrs libnet.${name} && libnet.${name} ? tryParse) (
    builtins.attrNames libnet
  );

  # At least 20000 characters: a parser that recursed once per character
  # or delimiter would exceed Nix's maximum call depth.
  repeat = unit: builtins.concatStringsSep "" (builtins.genList (_: unit) 20000);

  # Long text of the shapes the parsers split: on dots, colons, hyphens,
  # slashes, brackets, `@`, `%` and the URL scheme separator.
  inputs = {
    letters = repeat "a";
    digits = repeat "1";
    dottedLabels = repeat "a.";
    dottedDigits = repeat "1.";
    colons = repeat "1:";
    doubleColons = repeat "1::";
    hyphens = repeat "1-";
    slashes = repeat "1/";
    bracketed = "[${repeat "1:"}]:80";
    userinfo = repeat "a@";
    percentEncoded = repeat "%41";
    urlAuthority = "http://${repeat "a"}";
    urlPath = "http://a${repeat "/a"}";
    urlQuery = "http://a/?${repeat "a?#"}";
  };

  characters = text: builtins.genList (i: builtins.substring i 1 text) (builtins.stringLength text);

  capitalize =
    name:
    builtins.replaceStrings (characters "abcdefghijklmnopqrstuvwxyz")
      (characters "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
      (builtins.substring 0 1 name)
    + builtins.substring 1 (builtins.stringLength name) name;

  # The shapes a namespace accepts. A registered name has no length limit
  # (RFC 3986), so neither do the authority, URL host and URL forms built
  # on it.
  accepted =
    let
      regName = [
        "dottedLabels"
        "hyphens"
        "letters"
        "percentEncoded"
      ];
    in
    {
      authority = regName;
      inherit regName;
      url = [
        "urlAuthority"
        "urlPath"
      ];
      urlHost = regName;
    };

  # Compares a prefix rather than matching a regular expression, which
  # could exhaust the stack on a long error message.
  namesParse =
    namespace: error:
    let
      prefix = "libnet.${namespace}.parse: ";
    in
    builtins.substring 0 (builtins.stringLength prefix) error == prefix;

  mkTests =
    namespace:
    let
      module = libnet.${namespace};
      accepts = shape: builtins.elem shape (accepted.${namespace} or [ ]);
    in
    builtins.listToAttrs (
      builtins.concatMap (
        shape:
        let
          input = inputs.${shape};
          result = module.tryParse input;
        in
        [
          {
            name = "test${capitalize shape}IsValid";
            value = {
              expr = module.isValid input;
              expected = accepts shape;
            };
          }
          # A failure names `parse`, the function `tryParse` reports for.
          {
            name = "test${capitalize shape}TryParse";
            value =
              if accepts shape then
                {
                  expr = result.success;
                  expected = true;
                }
              else
                {
                  expr = {
                    inherit (result) success value;
                    namesParse = namesParse namespace result.error;
                  };
                  expected = {
                    success = false;
                    value = null;
                    namesParse = true;
                  };
                };
          }
        ]
      ) (builtins.attrNames inputs)
    );
in
builtins.listToAttrs (
  map (namespace: {
    name = namespace;
    value = mkTests namespace;
  }) namespaces
)
