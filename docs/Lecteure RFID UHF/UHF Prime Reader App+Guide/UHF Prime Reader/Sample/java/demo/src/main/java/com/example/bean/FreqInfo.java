package com.example.bean;

import lombok.Data;

@Data
public class FreqInfo {
    private int region;
    private String StartFreq;
    private String StopFreq;
    private String StepFreq;
    private int cnt;
    private int hComm;
}
