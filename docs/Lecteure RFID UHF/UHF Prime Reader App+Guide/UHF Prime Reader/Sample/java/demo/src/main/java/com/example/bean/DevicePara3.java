package com.example.bean;

import com.alibaba.fastjson.annotation.JSONField;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.sun.jna.Structure;
import com.sun.jna.ptr.ByteByReference;
import lombok.Data;


@Structure.FieldOrder(value= {"DEVICEARRD", "RFIDPRO", "WORKMODE", "INTERFACE", "BAUDRATE", "WGSET", "ANT"
        , "REGION",  "STRATFREI", "STRATFRED",
        "STEPFRE", "CN", "RFIDPOWER", "INVENTORYAREA", "QVALUE","SESSION", "ACSADDR", "ACSDATALEN", "FILTERTIME", "TRIGGLETIME", "BUZZERTIME"
        ,"INTERNELTIME"
})
public class DevicePara3 extends Structure {
  /*  @JsonProperty(value = "DEVICEARRD")
    @JSONField(name = "DEVICEARRD")*/
    public byte DEVICEARRD;

    public byte RFIDPRO;

    public byte WORKMODE;

    public byte INTERFACE;

    public byte BAUDRATE;

    public byte WGSET;

    public byte ANT;

    public byte REGION;

    public byte[] STRATFREI=new byte[2];

    public byte[] STRATFRED=new byte[2];

    public byte[] STEPFRE=new byte[2];

    public byte CN;

    public byte RFIDPOWER;

    public byte INVENTORYAREA;

    public byte QVALUE;

    public byte SESSION;

    public byte ACSADDR;
    public byte ACSDATALEN;
    public byte FILTERTIME;
    public byte TRIGGLETIME;
    public byte BUZZERTIME;
    public byte INTERNELTIME;


    public DevicePara3() {
        super(ALIGN_NONE);
    }
    public static class ByReference extends DevicePara3 implements Structure.ByReference {}
    public static class ByValue extends DevicePara3 implements Structure.ByValue{}

}
