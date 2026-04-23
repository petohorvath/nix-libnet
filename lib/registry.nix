/*
  libnet.registry

  Static lookup tables: bogon prefix lists for IPv4 and IPv6, common
  TCP/UDP well-known service ports, and ICMP / ICMPv6 type numbers.
  All entries are plain Nix literals — parse them through libnet.cidr
  or libnet.port as needed.

  Example:
    libnet.registry.wellKnownPorts.tcp.https
    => 443

    builtins.head libnet.registry.bogons.ipv4
    => "0.0.0.0/32"
*/
{
  bogons = {
    ipv4 = [
      "0.0.0.0/32"
      "10.0.0.0/8"
      "127.0.0.0/8"
      "169.254.0.0/16"
      "172.16.0.0/12"
      "192.0.2.0/24"
      "192.168.0.0/16"
      "198.51.100.0/24"
      "203.0.113.0/24"
      "224.0.0.0/4"
      "240.0.0.0/4"
    ];

    ipv6 = [
      "::/128"
      "::1/128"
      "2001:db8::/32"
      "3fff::/20"
      "fc00::/7"
      "fe80::/10"
      "ff00::/8"
    ];
  };

  wellKnownPorts = {
    tcp = {
      ftpData = 20;
      ftp = 21;
      ssh = 22;
      telnet = 23;
      smtp = 25;
      dns = 53;
      http = 80;
      pop3 = 110;
      imap = 143;
      bgp = 179;
      ldap = 389;
      https = 443;
      smtps = 465;
      submission = 587;
      ldaps = 636;
      dnsTls = 853;
      imaps = 993;
      pop3s = 995;
      mysql = 3306;
      rdp = 3389;
      postgres = 5432;
      rabbitmq = 5672;
      vnc = 5900;
      redis = 6379;
      irc = 6667;
      elasticsearch = 9200;
      memcached = 11211;
      mongodb = 27017;
    };

    udp = {
      dns = 53;
      ntp = 123;
      snmp = 161;
      snmpTrap = 162;
      dnsQuic = 853;
      rdp = 3389;
      memcached = 11211;
    };
  };

  icmpTypes = {
    ipv4 = {
      echoReply = 0;
      destinationUnreachable = 3;
      redirect = 5;
      echoRequest = 8;
      routerAdvertisement = 9;
      routerSolicitation = 10;
      timeExceeded = 11;
      parameterProblem = 12;
      extendedEchoRequest = 42;
      extendedEchoReply = 43;
    };

    ipv6 = {
      destinationUnreachable = 1;
      packetTooBig = 2;
      timeExceeded = 3;
      parameterProblem = 4;
      echoRequest = 128;
      echoReply = 129;
      multicastListenerQuery = 130;
      multicastListenerReport = 131;
      multicastListenerDone = 132;
      routerSolicitation = 133;
      routerAdvertisement = 134;
      neighborSolicitation = 135;
      neighborAdvertisement = 136;
      redirect = 137;
      multicastListenerReportV2 = 143;
      multicastRouterAdvertisement = 151;
      multicastRouterSolicitation = 152;
      multicastRouterTermination = 153;
      rplControl = 155;
      duplicateAddressRequest = 157;
      duplicateAddressConfirmation = 158;
      mplControl = 159;
      extendedEchoRequest = 160;
      extendedEchoReply = 161;
    };
  };
}
