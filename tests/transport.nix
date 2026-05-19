{ harness }:
let
  transport = import ../lib/transport.nix;
  inherit (harness) throws;
  p = transport.parse;
in
{
  # ===== Parse =====
  parse-tcp = {
    expr = (p "tcp").value;
    expected = "tcp";
  };
  parse-udp = {
    expr = (p "udp").value;
    expected = "udp";
  };
  parse-sctp = {
    expr = (p "sctp").value;
    expected = "sctp";
  };
  parse-tagged = {
    expr = (p "tcp")._type;
    expected = "transport";
  };

  reject-upper = {
    expr = throws (p "TCP");
    expected = true;
  };
  reject-mixed-case = {
    expr = throws (p "Tcp");
    expected = true;
  };
  reject-unknown = {
    expr = throws (p "icmp");
    expected = true;
  };
  reject-quic = {
    expr = throws (p "quic");
    expected = true;
  };
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-whitespace = {
    expr = throws (p " tcp");
    expected = true;
  };
  reject-trailing = {
    expr = throws (p "tcp ");
    expected = true;
  };
  reject-not-string = {
    expr = throws (transport.parse 6);
    expected = true;
  };

  tryParse-ok = {
    expr = (transport.tryParse "tcp").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (transport.tryParse "icmp").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (transport.tryParse "icmp").error;
    expected = true;
  };
  tryParse-not-string = {
    expr = (transport.tryParse 6).success;
    expected = false;
  };

  # ===== Round-trip =====
  rt-tcp = {
    expr = transport.toString (p "tcp");
    expected = "tcp";
  };
  rt-udp = {
    expr = transport.toString (p "udp");
    expected = "udp";
  };
  rt-sctp = {
    expr = transport.toString (p "sctp");
    expected = "sctp";
  };

  # ===== Predicates =====
  is-parsed = {
    expr = transport.is (p "tcp");
    expected = true;
  };
  is-string = {
    expr = transport.is "tcp";
    expected = false;
  };
  is-untagged = {
    expr = transport.is { value = "tcp"; };
    expected = false;
  };
  isValid-tcp = {
    expr = transport.isValid "tcp";
    expected = true;
  };
  isValid-udp = {
    expr = transport.isValid "udp";
    expected = true;
  };
  isValid-sctp = {
    expr = transport.isValid "sctp";
    expected = true;
  };
  isValid-bad = {
    expr = transport.isValid "icmp";
    expected = false;
  };
  isValid-not-string = {
    expr = transport.isValid 6;
    expected = false;
  };

  isTcp-tcp = {
    expr = transport.isTcp (p "tcp");
    expected = true;
  };
  isTcp-udp = {
    expr = transport.isTcp (p "udp");
    expected = false;
  };
  isTcp-sctp = {
    expr = transport.isTcp (p "sctp");
    expected = false;
  };
  isUdp-udp = {
    expr = transport.isUdp (p "udp");
    expected = true;
  };
  isUdp-tcp = {
    expr = transport.isUdp (p "tcp");
    expected = false;
  };
  isUdp-sctp = {
    expr = transport.isUdp (p "sctp");
    expected = false;
  };
  isSctp-sctp = {
    expr = transport.isSctp (p "sctp");
    expected = true;
  };
  isSctp-tcp = {
    expr = transport.isSctp (p "tcp");
    expected = false;
  };
  isSctp-udp = {
    expr = transport.isSctp (p "udp");
    expected = false;
  };

  # ===== Equality =====
  eq-same-tcp = {
    expr = transport.eq (p "tcp") (p "tcp");
    expected = true;
  };
  eq-same-udp = {
    expr = transport.eq (p "udp") (p "udp");
    expected = true;
  };
  eq-tcp-udp = {
    expr = transport.eq (p "tcp") (p "udp");
    expected = false;
  };
  eq-tcp-sctp = {
    expr = transport.eq (p "tcp") (p "sctp");
    expected = false;
  };

  # ===== Constants =====
  const-tcp = {
    expr = transport.eq transport.tcp (p "tcp");
    expected = true;
  };
  const-udp = {
    expr = transport.eq transport.udp (p "udp");
    expected = true;
  };
  const-sctp = {
    expr = transport.eq transport.sctp (p "sctp");
    expected = true;
  };
  const-tcp-tagged = {
    expr = transport.is transport.tcp;
    expected = true;
  };
  values-list = {
    expr = transport.values;
    expected = [
      "tcp"
      "udp"
      "sctp"
    ];
  };
}
