package com.example.bean;

//java DD_DATA 实体类定义是关键
import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;

import com.alibaba.fastjson.annotation.JSONField;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.sun.jna.Structure;
import com.sun.jna.ptr.ByteByReference;
import com.sun.jna.ptr.ShortByReference;
import lombok.Data;

@Data
public   class DevicePara2 {
    @JsonProperty(value = "DEVICEARRD")
    @JSONField(name = "DEVICEARRD")
    private int DEVICEARRD;
    @JsonProperty(value = "RFIDPRO")
    @JSONField(name = "RFIDPRO")
    private int RFIDPRO;
    @JsonProperty(value = "WORKMODE")
    @JSONField(name = "WORKMODE")
    private int WORKMODE;
    @JsonProperty(value = "INTERFACE")
    @JSONField(name = "INTERFACE")
    private int INTERFACE;
    @JsonProperty(value = "BAUDRATE")
    @JSONField(name = "BAUDRATE")
    private int BAUDRATE;
    @JsonProperty(value = "WGSET")
    @JSONField(name = "WGSET")
    private int WGSET;
    @JsonProperty(value = "ANT")
    @JSONField(name = "ANT")
    private int ANT;
    @JsonProperty(value = "REGION")
    @JSONField(name = "REGION")
    private int REGION;
    @JsonProperty(value = "STRATFREI")
    @JSONField(name = "STRATFREI")
    private BigDecimal STRATFREI;
    @JsonProperty(value = "STRATFRED")
    @JSONField(name = "STRATFRED")
    private float STRATFRED;
    @JsonProperty(value = "STEPFRE")
    @JSONField(name = "STEPFRE")
    private float STEPFRE;
    @JsonProperty(value = "CN")
    @JSONField(name = "CN")
    private int CN;
    @JsonProperty(value = "RFIDPOWER")
    @JSONField(name = "RFIDPOWER")
    private int RFIDPOWER;
    @JsonProperty(value = "INVENTORYAREA")
    @JSONField(name = "INVENTORYAREA")
    private int INVENTORYAREA;
    @JsonProperty(value = "QVALUE")
    @JSONField(name = "QVALUE")
    private int QVALUE;
    @JsonProperty(value = "SESSION")
    @JSONField(name = "SESSION")
    private int SESSION;
    @JsonProperty(value = "ACSADDR")
    @JSONField(name = "ACSADDR")
    private int ACSADDR;
    @JsonProperty(value = "ACSDATALEN")
    @JSONField(name = "ACSDATALEN")
    private int ACSDATALEN;
    @JsonProperty(value = "FILTERTIME")
    @JSONField(name = "FILTERTIME")
    private int FILTERTIME;
    @JsonProperty(value = "TRIGGLETIME")
    @JSONField(name = "TRIGGLETIME")
    private int TRIGGLETIME;
    @JsonProperty(value = "BUZZERTIME")
    @JSONField(name = "BUZZERTIME")
    private int BUZZERTIME;
    @JsonProperty(value = "INTERNELTIME")
    @JSONField(name = "INTERNELTIME")
    private int INTERNELTIME;
    @JsonProperty(value = "hComm")
    @JSONField(name = "hComm")
    private int hComm;



}
