package com.example.bean;

import com.alibaba.fastjson.annotation.JSONField;
import com.example.util.UnsignedByte;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.ptr.ByteByReference;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.ptr.ShortByReference;
import lombok.Data;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

@Data
public class DevicePara extends Structure {

    public DevicePara() {
        super(ALIGN_NONE);
    }
    public static class ByReference extends DevicePara implements Structure.ByReference {}
    public static class ByValue extends DevicePara implements Structure.ByValue{}

    @JsonProperty(value = "DEVICEARRD")
    @JSONField(name = "DEVICEARRD")
    public byte DEVICEARRD;
    @JsonProperty(value = "RFIDPRO")
    @JSONField(name = "RFIDPRO")
    public byte RFIDPRO;
    @JsonProperty(value = "WORKMODE")
    @JSONField(name = "WORKMODE")
    public byte WORKMODE;
    @JsonProperty(value = "INTERFACE")
    @JSONField(name = "INTERFACE")
    public byte INTERFACE;
    @JsonProperty(value = "BAUDRATE")
    @JSONField(name = "BAUDRATE")
    public byte BAUDRATE;
    @JsonProperty(value = "WGSET")
    @JSONField(name = "WGSET")
    public byte WGSET;
    @JsonProperty(value = "ANT")
    @JSONField(name = "ANT")
    public byte ANT;
    @JsonProperty(value = "REGION")
    @JSONField(name = "REGION")
    public byte REGION;
    @JsonProperty(value = "STRATFREI")
    @JSONField(name = "STRATFREI")
    public byte[] STRATFREI=new byte[2];
    @JsonProperty(value = "STRATFRED")
    @JSONField(name = "STRATFRED")
    public byte[] STRATFRED=new byte[2];
    @JsonProperty(value = "STEPFRE")
    @JSONField(name = "STEPFRE")
    public byte[] STEPFRE=new byte[2];
    @JsonProperty(value = "CN")
    @JSONField(name = "CN")
    public byte CN;
    @JsonProperty(value = "RFIDPOWER")
    @JSONField(name = "RFIDPOWER")
    public byte RFIDPOWER;
    @JsonProperty(value = "INVENTORYAREA")
    @JSONField(name = "INVENTORYAREA")
    public byte INVENTORYAREA;
    @JsonProperty(value = "QVALUE")
    @JSONField(name = "QVALUE")
    public byte QVALUE;
    @JsonProperty(value = "SESSION")
    @JSONField(name = "SESSION")
    public byte SESSION;
    @JsonProperty(value = "ACSADDR")
    @JSONField(name = "ACSADDR")
    public byte ACSADDR;
    @JsonProperty(value = "ACSDATALEN")
    @JSONField(name = "ACSDATALEN")
    public byte ACSDATALEN;
    @JsonProperty(value = "FILTERTIME")
    @JSONField(name = "FILTERTIME")
    public byte FILTERTIME;
    @JsonProperty(value = "TRIGGLETIME")
    @JSONField(name = "TRIGGLETIME")
    public byte TRIGGLETIME;
    @JsonProperty(value = "BUZZERTIME")
    @JSONField(name = "BUZZERTIME")
    public byte BUZZERTIME;
    @JsonProperty(value = "INTERNELTIME")
    @JSONField(name = "INTERNELTIME")
    public byte INTERNELTIME;
    @JsonProperty(value = "hComm")
    @JSONField(name = "hComm")
    private int hComm;

        @Override
        protected List<String> getFieldOrder() {
        return Arrays.asList("DEVICEARRD", "RFIDPRO","WORKMODE","INTERFACE","BAUDRATE","WGSET","ANT","REGION","STRATFREI","STRATFRED","STEPFRE","CN"
        ,"RFIDPOWER","INVENTORYAREA","QVALUE","SESSION","ACSADDR","ACSDATALEN","FILTERTIME","TRIGGLETIME","BUZZERTIME","INTERNELTIME");
        }


}
