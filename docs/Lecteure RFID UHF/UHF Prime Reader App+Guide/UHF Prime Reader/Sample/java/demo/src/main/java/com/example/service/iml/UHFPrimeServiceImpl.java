package com.example.service.iml;

import com.example.bean.DevicePara;
import com.example.bean.RunnableImpl;
import com.example.bean.TagInfo;
import com.example.bean.TagInfoReturn;
import com.example.service.CLibrary;
import com.example.service.UHFPrimeService;
import com.example.util.TypeConversionUtil;
import com.sun.jna.ptr.ByteByReference;
import com.sun.jna.ptr.IntByReference;
import gnu.io.CommPortIdentifier;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.util.CollectionUtils;
import org.springframework.util.StringUtils;

import java.io.*;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.List;


@Service
@EnableAsync
public class UHFPrimeServiceImpl implements UHFPrimeService {
    public static   HashMap<String, TagInfoReturn> hashMap= new HashMap<String,TagInfoReturn>();
    Thread thread = null;

    @Override
    public  void startCounting(DevicePara devicePara) {
        IntByReference intByReference=CLibrary.INSTANCE.SetDevicePara_J(devicePara.getHComm(), devicePara.DEVICEARRD, devicePara.RFIDPRO,devicePara.WORKMODE, (byte)128,devicePara.BAUDRATE, devicePara.WGSET, devicePara.ANT,devicePara.REGION,
                devicePara.STRATFREI[0], devicePara.STRATFREI[1],
                devicePara.STRATFRED[0], devicePara.STRATFRED[1],
                devicePara.STEPFRE[0], devicePara.STEPFRE[1],
                devicePara.CN, devicePara.RFIDPOWER, devicePara.INVENTORYAREA,
                devicePara.QVALUE, devicePara.SESSION, devicePara.ACSADDR,
                devicePara.ACSDATALEN, devicePara.FILTERTIME, devicePara.TRIGGLETIME,
                devicePara.BUZZERTIME, devicePara.INTERNELTIME);
        if(thread!=null){
           // CLibrary.INSTANCE.InventoryContinue(hComm,btInvCount,1000);
            thread.interrupt();
        }
        hashMap=new HashMap<String,TagInfoReturn>();
        HashMap<String, Object> returnMap = new HashMap<>();
        if (0 == devicePara.getWORKMODE()) {
            IntByReference reference = CLibrary.INSTANCE.InventoryContinue(devicePara.getHComm(), new Byte("0"), 0);
            String data = TypeConversionUtil.typeConversion(reference);
            if(!StringUtils.isEmpty(data)){
                returnMap.put("data",data);
                returnMap.put("log",null);
                returnMap.put("msgB",null);
                returnMap.put("res_code",1000);
            }
        }else{

        }
        RunnableImpl run = new RunnableImpl(UHFPrimeServiceImpl.hashMap,devicePara.getHComm());
        Thread thread2 = new Thread(run);
        thread2.start();
        thread =thread2;

    }

    @Override
    public void stopCounting(){
        if(thread!=null){
            try {
                Thread.sleep(200);
                thread.interrupt();
            } catch (InterruptedException e) {
                hashMap.clear();
                e.printStackTrace();
            }

        }
    }

    public ArrayList<TagInfoReturn> getTagInfos() {
        if (CollectionUtils.isEmpty(hashMap)) {
            return null;
        }
        return new ArrayList(hashMap.values());
    }


    @SuppressWarnings("unchecked")
    public List<String> getSerialPortList() {
        List<String> systemPorts = new ArrayList<>();
        Enumeration<CommPortIdentifier> portList = CommPortIdentifier.getPortIdentifiers();
        while (portList.hasMoreElements()) {
            String portName = portList.nextElement().getName();
            systemPorts.add(portName);
        }
        return systemPorts;
    }


    /**
     * Access to a serial port,
     */
    public void accessSerialPort(){
        ArrayList<String> list = execRootCmd("reg query \"HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB\" /s /v FriendlyName");
    }

    @Override
    public  ArrayList<String> execRootCmd(String cmd) {
        ArrayList<String> list = new ArrayList<>();
        String result = "";
        DataOutputStream dos = null;
        DataInputStream dis = null;
        try {
            Process p = Runtime.getRuntime().exec(cmd);
            dos = new DataOutputStream(p.getOutputStream());
            dis = new DataInputStream(p.getInputStream());
            dos.writeBytes(cmd + "\n");
            dos.flush();
            dos.writeBytes("exit\n");
            dos.flush();
            String line = null;
            BufferedReader br = new BufferedReader(new InputStreamReader(dis));
            while ((line = br.readLine()) != null) {
                if(!StringUtils.isEmpty(line) && line.contains("(COM")){
                    String substring = line.substring(line.indexOf("(")+1, line.indexOf(")"));
                    list.add(substring);
                    System.out.println("Access to the port"+substring);
                }
                System.out.println( "result:" + line);
                result += line;
            }
            p.waitFor();
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            if (dos != null) {
                try {
                    dos.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
            if (dis != null) {
                try {
                    dis.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        return list;
    }

}
