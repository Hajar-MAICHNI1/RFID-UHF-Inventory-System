package com.example.bean;

import com.sun.jna.Structure;
import com.sun.jna.ptr.ByteByReference;
import lombok.Data;

@Data

public class TagInfoReturn {
    public long m_no;
    public long m_rssi;
    public String m_ant;
    public String m_channel;
    public String m_crc;
    public String m_pc;
    public long m_len;
    public String m_code;
    public int [] counts;
    public String m_counts;
   // public Long number;

}
