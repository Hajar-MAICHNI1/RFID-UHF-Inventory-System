package com.example.bean;

import lombok.Data;

@Data
public class QueryParam {
    private String condition;
    private String  session;
    private String  target;
    private int hComm;
    private String proto;
}
