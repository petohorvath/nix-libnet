{ libnet, ... }:
let
  # Sample texts per namespace with a comparison suite, including
  # spellings that differ without changing meaning (case, a default port,
  # an empty URL path for `/`, an input spelling such as `ssl`), so that
  # both outcomes of `eq` occur.
  # Mixed-case names parse to the same value (ADR 0020); interface names
  # keep their case, so `eth0` and `ETH0` differ.
  samples = {
    authority = [
      "example.com"
      "Example.COM"
      "example.com:443"
      "u@example.com:443"
      "v@example.com:443"
    ];
    bindUrl = [
      "tcp://:8080"
      "TCP://:8080"
      "tcp://0.0.0.0:8080"
      "sctp://:8080"
      "unix:///run/a.sock"
    ];
    bindpoint = [
      ":8080"
      "*:8080"
      "[::1]:8080"
      "/run/a.sock"
    ];
    cidr = [
      "192.0.2.0/24"
      "192.0.2.0/25"
      "2001:db8::/32"
      "2001:DB8::/32"
    ];
    dnsEndpoint = [
      "example.com:80"
      "Example.COM:80"
      "example.com:81"
      "host:80"
    ];
    dnsName = [
      "host"
      "HOST"
      "example.com"
      "Example.com"
    ];
    domain = [
      "example.com"
      "Example.COM"
      "example.org"
    ];
    endpoint = [
      "192.0.2.1:80"
      "example.com:80"
      "EXAMPLE.com:80"
      "/run/a.sock"
    ];
    host = [
      "192.0.2.1"
      "2001:db8::1"
      "host"
      "Host"
      "example.com"
    ];
    hostname = [
      "host"
      "HOST"
      "other"
    ];
    icmpType = [
      "0"
      "8"
    ];
    interfaceAddress = [
      "192.0.2.1/24"
      "192.0.2.1/25"
      "192.0.2.2/24"
      "2001:db8::1/64"
    ];
    interfaceName = [
      "eth0"
      "ETH0"
      "eth1"
    ];
    ip = [
      "192.0.2.1"
      "::ffff:192.0.2.1"
      "2001:db8::1"
      "2001:DB8::1"
    ];
    ipBindpoint = [
      ":8080"
      "*:8080"
      "any:8080"
      "0.0.0.0:8080"
      "[::]:8080"
      "192.0.2.1:8000-8100"
    ];
    ipEndpoint = [
      "192.0.2.1:80"
      "[2001:db8::1]:80"
      "[2001:DB8::1]:80"
      "192.0.2.1:81"
    ];
    ipRange = [
      "192.0.2.1-192.0.2.2"
      "192.0.2.1-192.0.2.3"
      "2001:db8::1-2001:DB8::2"
      "2001:db8::1-2001:db8::2"
    ];
    ipv4 = [
      "192.0.2.1"
      "192.0.2.2"
    ];
    ipv6 = [
      "2001:db8::1"
      "2001:DB8:0::1"
      "::1"
    ];
    mac = [
      "02:00:00:00:00:01"
      "02-00-00-00-00-01"
      "0200.0000.0001"
      "02:00:00:00:00:02"
    ];
    mtu = [
      "1280"
      "1500"
    ];
    port = [
      "80"
      "443"
    ];
    portRange = [
      "80"
      "80-80"
      "80-81"
      "80:81"
      "81-90"
    ];
    proxyUrl = [
      "socks5://h:1080"
      "SOCKS5://H:1080"
      "socks5h://h:1080"
      "socks5://u@h:1080"
      "http://h:1080"
    ];
    regName = [
      "my_host"
      "MY_HOST"
      "a%2fb"
      "A%2Fb"
      "other"
    ];
    secureSocketUrl = [
      "tls://192.0.2.1:443"
      "ssl://192.0.2.1:443"
      "dtls://192.0.2.1:443"
      "quic://192.0.2.1:443"
    ];
    socketUrl = [
      "tcp://192.0.2.1:80"
      "TCP://192.0.2.1:80"
      "udp://192.0.2.1:80"
      "tcp://Example.COM:80"
      "tcp://example.com:80"
      "unix:///run/a.sock"
    ];
    transport = [
      "sctp"
      "tcp"
      "udp"
    ];
    unixSocket = [
      "/run/a.sock"
      "/run/b.sock"
      "@a"
    ];
    url = [
      "https://example.com"
      "https://example.com/"
      "https://Example.COM:443/"
      "https://example.com:8443"
      "https://u@example.com"
      "https://u@example.com:443"
      "https://v@example.com"
      "https://example.com/p"
      "https://example.com/p?q"
      "https://example.com/p#f"
      "http://example.com"
    ];
    urlHost = [
      "example.com"
      "EXAMPLE.com"
      "a%2f"
      "a%2F"
      "192.0.2.1"
      "[::1]"
      "[0::1]"
    ];
    vlanId = [
      "100"
      "200"
    ];
  };

  # The pairs, as texts, where `compare a b == 0` disagrees with `eq a b`.
  disagreements =
    name: texts:
    let
      module = libnet.${name};
    in
    builtins.concatMap (
      textA:
      builtins.concatMap (
        textB:
        let
          a = module.parse textA;
          b = module.parse textB;
        in
        if (module.compare a b == 0) == module.eq a b then
          [ ]
        else
          [
            [
              textA
              textB
            ]
          ]
      ) texts
    ) texts;

  # Kinds whose `parse` folds every spelling that `eq` ignores, so that
  # `eq`, and `compare a b == 0`, hold exactly when the values are equal.
  structural = [
    "dnsName"
    "domain"
    "host"
    "hostname"
    "interfaceName"
    "regName"
    "urlHost"
  ];

  # The pairs, as texts, where `eq a b` disagrees with `a == b`.
  nonStructural =
    name: texts:
    let
      module = libnet.${name};
    in
    builtins.concatMap (
      textA:
      builtins.concatMap (
        textB:
        let
          a = module.parse textA;
          b = module.parse textB;
        in
        if module.eq a b == (a == b) then
          [ ]
        else
          [
            [
              textA
              textB
            ]
          ]
      ) texts
    ) texts;

  namespacesWithCompare = builtins.filter (
    name: builtins.isAttrs libnet.${name} && libnet.${name} ? compare
  ) (builtins.attrNames libnet);

  lowerLetters = [
    "a"
    "b"
    "c"
    "d"
    "e"
    "f"
    "g"
    "h"
    "i"
    "j"
    "k"
    "l"
    "m"
    "n"
    "o"
    "p"
    "q"
    "r"
    "s"
    "t"
    "u"
    "v"
    "w"
    "x"
    "y"
    "z"
  ];
  upperLetters = [
    "A"
    "B"
    "C"
    "D"
    "E"
    "F"
    "G"
    "H"
    "I"
    "J"
    "K"
    "L"
    "M"
    "N"
    "O"
    "P"
    "Q"
    "R"
    "S"
    "T"
    "U"
    "V"
    "W"
    "X"
    "Y"
    "Z"
  ];
  capitalize =
    name:
    builtins.replaceStrings lowerLetters upperLetters (builtins.substring 0 1 name)
    + builtins.substring 1 (builtins.stringLength name) name;
in
{
  testSamplesCoverEveryComparableNamespace = {
    expr = builtins.attrNames samples;
    expected = namespacesWithCompare;
  };
}
// builtins.listToAttrs (
  map (name: {
    name = "test${capitalize name}IsStructural";
    value = {
      expr = nonStructural name samples.${name};
      expected = [ ];
    };
  }) structural
)
// builtins.listToAttrs (
  map (name: {
    name = "test${capitalize name}";
    value = {
      expr = disagreements name samples.${name};
      expected = [ ];
    };
  }) (builtins.attrNames samples)
)
