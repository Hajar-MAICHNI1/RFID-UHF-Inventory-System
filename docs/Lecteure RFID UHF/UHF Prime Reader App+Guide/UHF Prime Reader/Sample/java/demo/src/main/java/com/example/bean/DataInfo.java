package com.example.bean;

import lombok.Data;

@Data
public class DataInfo {
    public DataInfo(Object data, String log, String msgB, String res_code,int   hComm) {
        this.data = data;
        this.log = log;
        this.msgB = msgB;
        this.res_code = res_code;
        this.hComm = hComm;
    }
    public DataInfo(Object data, String log, String msgB, String res_code) {
        this.data = data;
        this.log = log;
        this.msgB = msgB;
        this.res_code = res_code;
    }

    private Object   data;
    private String   log;
    private String   msgB;
    private String   res_code;
    private int   hComm;

    public DataInfo() {
    }
}
