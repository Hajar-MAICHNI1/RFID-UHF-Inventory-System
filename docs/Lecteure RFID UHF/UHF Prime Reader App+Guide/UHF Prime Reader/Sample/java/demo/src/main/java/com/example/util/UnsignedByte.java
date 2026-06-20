package com.example.util;

public class UnsignedByte {
    private short value;
    private byte rawValue;

    private UnsignedByte() {
    }

    public static UnsignedByte toUnsignedByte(byte b) {
        UnsignedByte ub = new UnsignedByte();
        ub.rawValue = b;
        ub.value = (short) ((short) b & 0xFF);

        return ub;
    }

    public static byte toByte(UnsignedByte b) {
        return b.rawValue;
    }

    public static byte toByte(short i) {
        return (byte)i;
    }
}
