package com.example.bean;

import lombok.Data;

@Data
public class NetInfo {
    private byte IP;
    private byte MAC;
    private byte PORT;
    private byte NetMask;
    private byte Gateway;
     private int hComm;
}
