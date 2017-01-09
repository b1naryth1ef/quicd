module quicd.types;


import std.bitmanip : peek, nativeToLittleEndian, Endian;
// import std.bitmanip : writeBits = write;


private enum Flags {
  PUBLIC_FLAG_VERSION = 0x01,
  PUBLIC_FLAG_RESET = 0x02,
  DIVERSIFICATION_SET = 0x04,
  CONNECTION_ID_SET = 0x08,
  RESERVED_MULTIPATH = 0x40,
  RESERVED_UNUSED = 0x80,
}


struct PublicPacketHeader {
  byte flags;
  ulong connectionID;
  byte[4] ver;
  string diversification;
  ulong packetNumber;

  /// Creates a Public Version Negotitation packet
  @safe static byte[] createVersionNegotitation(immutable ulong connectionID, immutable byte[4][] supportedVersions) {
    // Preallocate, 1 byte for flags, 8 bytes for CID, 4 * length bytes for versions
    byte[] result = new byte[](
      9 + (4 * supportedVersions.length)
    );

    result[0] = Flags.PUBLIC_FLAG_VERSION | Flags.CONNECTION_ID_SET;
    result[1..9] = cast(byte[8])nativeToLittleEndian(connectionID);

    foreach (offset, byte[4] sversion; supportedVersions) {
      result[9 + (offset * 4)..9 + (offset * 4) + 4] = sversion;
    }

    return result;
  }

  @safe @nogc @property pure nothrow bool hasReset() {
    return (this.flags & Flags.PUBLIC_FLAG_RESET) == Flags.PUBLIC_FLAG_RESET;
  }

  @safe @nogc @property pure nothrow bool hasVersion() {
    return (this.flags & Flags.PUBLIC_FLAG_VERSION) == Flags.PUBLIC_FLAG_VERSION;
  }

  @safe @nogc @property pure nothrow bool hasConnectionID() {
    return (this.flags & Flags.CONNECTION_ID_SET) == Flags.CONNECTION_ID_SET;
  }

  @nogc void write(ref byte[51] data) {
    
  }

  @safe @nogc pure nothrow void read(byte[] data) {
    this.flags = data[0];

    if (this.hasReset) {
      return;
    }

    if (this.hasVersion) {
      this.ver = data[9..13];

      version (SANITY_CHECKS) {
        assert(this.ver[0] == 'Q', "Invalid QUIC Version");
      }
    }

    if (this.hasConnectionID) {
      this.connectionID = peek!(ulong, Endian.littleEndian)(cast(ubyte[])data[1..9]);
    }
  }
}