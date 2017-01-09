module quicd.server;

import std.stdio : writefln;
import std.socket : UdpSocket, Address, InternetAddress, SocketType, ProtocolType;
import core.thread : Thread;
import quicd.types : PublicPacketHeader;
import std.algorithm.searching : canFind;


// TODO: determine how we actually want to decide this
immutable byte[4][] SUPPORTED_VERSIONS = [
  ['Q', '0', '3', '6'],
];


class QUICServerClient {
  private {
    ulong cid;
    Address source;
    UdpSocket socket;
  }

  this(Address source, ulong cid, UdpSocket socket) {
    this.source = source;
    this.cid = cid;
    this.socket = socket;
  }

  /// Whether the version has been fully negotitated
  bool versionNegotiated;

  void handleIncomingData(PublicPacketHeader header) {
    // CASE A: New connection, version is not negotatied, header is set
    if (!this.versionNegotiated && header.hasVersion) {
      // Happy path, the client has a version we support
      if (SUPPORTED_VERSIONS.canFind(header.ver)) {
        this.versionNegotiated = true; 
      // Sad path, we must send a version negotitation
      } else {
        writefln("Responding with negotation");
        this.socket.sendTo(PublicPacketHeader.createVersionNegotitation(
          this.cid,
          SUPPORTED_VERSIONS,
        ));
      }
    // CASE B: New connection, version is not negotitated, header is not set
    } else if (!this.versionNegotiated && !header.hasVersion) {
      // TODO: reset?
    }

    writefln("Flags: %s", header.flags);
    writefln("Version: %s", cast(string)header.ver);
    writefln("Connection ID: %s", header.connectionID);
  }
}


class QUICServer {
  UdpSocket socket;
  QUICServerClient[Address] clients;

  private {
    bool alive = false;
  }
 
  this(InternetAddress addr) {
    this.socket = new UdpSocket();
    this.socket.bind(addr);
  }

  void handleIncomingData(Address source, byte[] data) {
    PublicPacketHeader header;

    writefln("Read %s bytes from %s", data.length, source);
    header.read(data);
  
    // Check if this is an existing connection
    if ((source in this.clients) is null) {
      assert(header.hasConnectionID, "Missing connection id, but new connection?");

      if (header.hasConnectionID) {
        this.clients[source] = new QUICServerClient(source, header.connectionID, this.socket);
      }
    } else {
      this.clients[source].handleIncomingData(header);
    }

  }

  void run() {
    this.alive = true;

    Address source;
    size_t bytes;
    byte[2048] data;

    while (this.alive) {
      bytes = socket.receiveFrom(data, source);

      this.handleIncomingData(source, data[0..bytes]);
    }
  }
}

unittest {
  auto server = new QUICServer(new InternetAddress(4040));
  server.run();
}