package com.example.bean;

import com.alibaba.fastjson.JSONObject;
import com.example.enmu.ErrorEnmu;
import com.example.service.CLibrary;
import com.example.util.TypeConversionUtil;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.IntByReference;
import lombok.extern.slf4j.Slf4j;
import org.springframework.util.StringUtils;

import java.util.HashMap;
import java.util.List;

@Slf4j
public class RunnableImpl implements Runnable {
    private int ticket = 0;

    public RunnableImpl() {
    }
    public RunnableImpl(HashMap<String, TagInfoReturn> hashMap, int hComm) {
        this.hashMap = hashMap;
        this.hComm = hComm;
    }

    private HashMap<String,TagInfoReturn> hashMap;
    private int hComm;
    @Override
    public void run() {
        while (true) {
            synchronized (hashMap){
                if (!Thread.currentThread().isInterrupted()) {
                    try {
                        Thread.sleep(100);//Let the program dormancy 10 milliseconds
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                            log.info("Thread to stop"+ e);
                            hashMap.clear();;
                            break;
                    }
                    TagInfo tagInfo = new TagInfo();
                    IntByReference intByReference = CLibrary.INSTANCE.GetTagUii(hComm, tagInfo, 1000);
                        String mCode = TypeConversionUtil.conver16HexStr(tagInfo.m_code,12);
                        if(!StringUtils.isEmpty(mCode) ){
                            String code = mCode.substring(0, mCode.length() - 1);
                            if(!hashMap.containsKey(code)){
                                if (tagInfo.m_ant > 0 && tagInfo.m_ant <= 4) {
                                    int[] m_counts = new int[4];
                                    m_counts[tagInfo.m_ant - 1] = 1;
                                    TagInfoReturn tagInfoReturn = new TagInfoReturn();
                                    tagInfoReturn.setCounts(m_counts);
                                    tagInfoReturn.setM_rssi(tagInfo.m_rssi/10);
                                    tagInfoReturn.setM_ant(String.valueOf(tagInfo.m_ant));
                                    tagInfoReturn.setM_channel(String.valueOf(tagInfo.m_channel));
                                    tagInfoReturn.setM_crc(String.valueOf(tagInfo.m_crc));
                                    tagInfoReturn.setM_pc(String.valueOf(tagInfo.m_pc));
                                    tagInfoReturn.setM_len(tagInfo.m_len);
                                    tagInfoReturn.setM_code(code);
                                    //tagInfoReturn.setNumber(0L);
                                    hashMap.put(code,tagInfoReturn);
                                }
                            }else{
                                TagInfoReturn tagInfoReturn = hashMap.get(code);
                               // tagInfoReturn.setNumber( tagInfoReturn.getNumber()+1);
                                tagInfoReturn.setM_rssi(tagInfo.m_rssi/10);
                                hashMap.put(code,tagInfoReturn);
                                if (tagInfo.m_ant > 0 && tagInfo.m_ant <= 4){
                                    tagInfoReturn.getCounts()[tagInfo.m_ant -1] += 1;
                                }
                            }
                        }
                        System.out.println(Thread.currentThread().getName()+ "Article is to read the label information first" + ticket + "data "+JSONObject.toJSON(tagInfo));
                        if (intByReference !=null){
                            Pointer pointer = intByReference.getPointer();
                            String s= pointer.toString().split("native@")[1];
                            String data = ErrorEnmu.getName(s);
                        }
                    ticket++;
                } else {
                    break;
                }
            }
        }
    }

}
