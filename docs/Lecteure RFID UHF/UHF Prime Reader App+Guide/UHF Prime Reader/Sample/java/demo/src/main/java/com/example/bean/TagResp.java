package com.example.bean;

import lombok.Data;

@Data
public class TagResp {
    private String tagStatus;
    private String antenna;
    private String crc;
    private String pc;
    private String codeLen;
    private String code;
    private  int hComm;
    private  String wordCount;
    private String readData;
    private int timeout;
    private int cmd;
}
