_:
let
  libnet = import ../.;

  cases = {
    ipv4 = {
      module = libnet.ipv4;
      value = libnet.ipv4.parse "192.0.2.1";
    };
    ipv6 = {
      module = libnet.ipv6;
      value = libnet.ipv6.parse "2001:db8::1";
    };
    ip = {
      module = libnet.ip;
      value = libnet.ip.parse "192.0.2.1";
    };
    mac = {
      module = libnet.mac;
      value = libnet.mac.parse "02:00:00:00:00:01";
    };
    cidr = {
      module = libnet.cidr;
      value = libnet.cidr.parse "192.0.2.0/24";
    };
    port = {
      module = libnet.port;
      value = libnet.port.fromInt 80;
    };
    portRange = {
      module = libnet.portRange;
      value = libnet.portRange.parse "80-81";
    };
    ipEndpoint = {
      module = libnet.ipEndpoint;
      value = libnet.ipEndpoint.parse "192.0.2.1:80";
    };
    dnsEndpoint = {
      module = libnet.dnsEndpoint;
      value = libnet.dnsEndpoint.parse "example.com:80";
    };
    endpoint = {
      module = libnet.endpoint;
      value = libnet.endpoint.parse "192.0.2.1:80";
    };
    unixSocket = {
      module = libnet.unixSocket;
      value = libnet.unixSocket.parse "/run/example.sock";
    };
    socketUrl = {
      module = libnet.socketUrl;
      value = libnet.socketUrl.parse "tcp://192.0.2.1:80";
    };
    bindUrl = {
      module = libnet.bindUrl;
      value = libnet.bindUrl.parse "tcp://192.0.2.1:80";
    };
    secureSocketUrl = {
      module = libnet.secureSocketUrl;
      value = libnet.secureSocketUrl.parse "tls://192.0.2.1:443";
    };
    url = {
      module = libnet.url;
      value = libnet.url.parse "https://example.com/";
    };
    urlHost = {
      module = libnet.urlHost;
      value = libnet.urlHost.parse "example.com";
    };
    authority = {
      module = libnet.authority;
      value = libnet.authority.parse "example.com:443";
    };
    proxyUrl = {
      module = libnet.proxyUrl;
      value = libnet.proxyUrl.parse "http://example.com:8080";
    };
    ipBindpoint = {
      module = libnet.ipBindpoint;
      value = libnet.ipBindpoint.parse "192.0.2.1:80";
    };
    bindpoint = {
      module = libnet.bindpoint;
      value = libnet.bindpoint.parse "192.0.2.1:80";
    };
    ipRange = {
      module = libnet.ipRange;
      value = libnet.ipRange.parse "192.0.2.1-192.0.2.2";
    };
    interfaceAddress = {
      module = libnet.interfaceAddress;
      value = libnet.interfaceAddress.parse "192.0.2.1/24";
    };
    interfaceName = {
      module = libnet.interfaceName;
      value = libnet.interfaceName.parse "eth0";
    };
    transport = {
      module = libnet.transport;
      value = libnet.transport.parse "tcp";
    };
    hostname = {
      module = libnet.hostname;
      value = libnet.hostname.parse "host";
    };
    domain = {
      module = libnet.domain;
      value = libnet.domain.parse "example.com";
    };
    dnsName = {
      module = libnet.dnsName;
      value = libnet.dnsName.parse "example.com";
    };
    host = {
      module = libnet.host;
      value = libnet.host.parse "example.com";
    };
    vlanId = {
      module = libnet.vlanId;
      value = libnet.vlanId.fromInt 80;
    };
    mtu = {
      module = libnet.mtu;
      value = libnet.mtu.fromInt 1280;
    };
    icmpType = {
      module = libnet.icmpType;
      value = libnet.icmpType.fromInt 80;
    };
  };

  # Every tagged type's `eq` must reject a foreign `_type`, whether the
  # foreign value mirrors the case's fields or carries only the tag, and
  # must return false rather than throw for values with no `_type` at all.
  mkTests =
    case:
    let
      foreignClone = case.value // {
        _type = "foreign";
      };
      sparseForeign = {
        _type = "foreign";
      };
      untaggedValue = {
        value = 1;
      };
    in
    {
      testEmptyAttrsRight = {
        expr = case.module.eq case.value { };
        expected = false;
      };
      testEmptyAttrsLeft = {
        expr = case.module.eq { } case.value;
        expected = false;
      };
      testUntaggedRight = {
        expr = case.module.eq case.value untaggedValue;
        expected = false;
      };
      testUntaggedLeft = {
        expr = case.module.eq untaggedValue case.value;
        expected = false;
      };
      testNonAttrsRight = {
        expr = case.module.eq case.value 1;
        expected = false;
      };
      testNonAttrsLeft = {
        expr = case.module.eq null case.value;
        expected = false;
      };
      testForeignClone = {
        expr = case.module.eq case.value foreignClone;
        expected = false;
      };
      testSparseForeignRight = {
        expr = case.module.eq case.value sparseForeign;
        expected = false;
      };
      testSparseForeignLeft = {
        expr = case.module.eq sparseForeign case.value;
        expected = false;
      };
    };
in
builtins.mapAttrs (_: mkTests) cases
