package com.example.service;

import com.example.bean.DevicePara;
import com.example.bean.TagInfo;
import com.example.bean.TagInfoReturn;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public interface UHFPrimeService {
    List<String> getSerialPortList();

    void startCounting(DevicePara devicePara);

    void stopCounting();

    ArrayList<TagInfoReturn> getTagInfos();

    ArrayList<String> execRootCmd(String cmd);
}
