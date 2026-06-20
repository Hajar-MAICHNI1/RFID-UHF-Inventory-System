package com.example.bean;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.sun.jna.Structure;
import com.sun.jna.ptr.ByteByReference;
import com.sun.jna.ptr.IntByReference;
import lombok.Data;

@Structure.FieldOrder(value= { "m_no","m_rssi","m_ant","m_channel","m_crc","m_pc","m_len","m_code"})
public class TagInfo extends Structure  {
    public short m_no;
    public short m_rssi;
    public byte m_ant;
    public byte m_channel;
    public byte[] m_crc=new byte[2];
    public byte[] m_pc=new byte[2];
    public byte m_len;
    public byte[] m_code=new byte[255];
    public TagInfo() {
        super(ALIGN_NONE);
    }
    public static class ByReference extends TagInfo implements Structure.ByReference {}
    public static class ByValue extends TagInfo implements Structure.ByValue{}
}
