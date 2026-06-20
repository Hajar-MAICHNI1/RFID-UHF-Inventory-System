package com.example.bean;

import lombok.Data;

@Data
public class DeviceInfo extends  DataInfo{
    private int firmVersion;
    private int hardVersion;
    private int sn;
    private int para;
    private int rfidpro;
    private String stratfrei;
    private String stratfred;
    private String stepfre;
    private int cn;
    private int power;
    private int antenna;
    private int region;
    private int reserved;
    private int hComm;
}
