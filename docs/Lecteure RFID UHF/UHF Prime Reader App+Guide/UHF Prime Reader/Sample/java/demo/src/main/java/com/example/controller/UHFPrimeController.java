package com.example.controller;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONObject;
import com.example.bean.*;
import com.example.enmu.ResultCodeEnum;
import com.example.result.DataResponse;
import com.example.service.CLibrary;
import com.example.service.UHFPrimeService;
import com.example.util.TypeConversionUtil;
import com.sun.jna.ptr.ByteByReference;
import com.sun.jna.ptr.IntByReference;

import org.springframework.beans.factory.annotation.Autowired;


import org.springframework.util.CollectionUtils;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.util.*;

@RestController
@RequestMapping("/")
public class UHFPrimeController {

    @Autowired
    UHFPrimeService uhfPrimeService;


    /**
     * Connected to a serial port
     * @return
     */
    @PostMapping("/OpenDevice")
    public DataResponse OpenDevice(@RequestBody HashMap<String,Object> hashMap){
        IntByReference hComm= new IntByReference();
        try {
            String comPort = (String)hashMap.get("strComPort");
            byte Baudrate =TypeConversionUtil.intTobyte((int)hashMap.get("Baudrate"));
            IntByReference intByReference = CLibrary.INSTANCE.OpenDevice(hComm, comPort,new ByteByReference(Baudrate) );
            String data = TypeConversionUtil.typeConversion(intByReference);
            HashMap<String, Object> map = new HashMap<>();
            map.put("hComm",hComm.getValue());
            map.put("data",data);
            if(StringUtils.isEmpty(data)){
                map.put("data",TypeConversionUtil.success);
            }
            map.put("log",null);
            map.put("msgB",null);
            map.put("res_code",1000);
            return new DataResponse<>(map);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }

    /**
     * Connect the front-end ports
     * @return
     */
    @PostMapping("/OpenNetConnection")
    public DataResponse OpenNetConnection(@RequestBody HashMap<String,Object> map){
        try {
            String ip=(String)map.get("ip");
            int port=Integer.parseInt((String)map.get("port"));
            int timeoutMs=(int)map.get("timeoutMs");
            IntByReference hComm = new IntByReference();
            IntByReference intByReference = CLibrary.INSTANCE.OpenNetConnection(hComm,ip , port,timeoutMs);
            String data = TypeConversionUtil.typeConversion(intByReference);

            HashMap<String, Object> hashMap = new HashMap<>();
            hashMap.put("hComm",hComm.getValue());
            hashMap.put("data",data);
            if(StringUtils.isEmpty(data)){
                hashMap.put("data",TypeConversionUtil.success);
            }
            hashMap.put("log",null);
            hashMap.put("msgB",null);
            hashMap.put("res_code",1000);
            return new DataResponse<>(hashMap);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }

    /**
     * Close the card reader connected
     * @return
     */
    @PostMapping("/CloseDevice")
    public DataResponse CloseDevice(@RequestBody HashMap<String,Object> map ){
        try {
            int hComm =Integer.parseInt((String) map.get("hComm")) ;
            IntByReference intByReference = CLibrary.INSTANCE.CloseDevice(hComm);
            String data = TypeConversionUtil.typeConversion(intByReference);
            if(StringUtils.isEmpty(data)){
                data=TypeConversionUtil.success;
            }
            DataInfo dataInfo = new DataInfo(data,null,null,"1000");
            return new DataResponse<>(dataInfo);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }

    /**
     * Access to equipment parameter command
     * @return
     */
    @PostMapping("/GetDevicePara")
    public DataResponse GetDevicePara(@RequestBody HashMap<String,Object> map){
        try {
            int hComm =Integer.parseInt((String) map.get("hComm")) ;
            DevicePara.ByReference devicePara = new DevicePara.ByReference();
            IntByReference intByReference = CLibrary.INSTANCE.GetDevicePara( hComm, devicePara);
            System.out.println(JSONObject.toJSONString(devicePara));
            byte[] stratfrei = devicePara.STRATFREI;
            byte[] stratfred =devicePara.STRATFRED;
            byte[] stepfre = devicePara.STEPFRE;
            int freq = TypeConversionUtil.byteToInt(stratfrei[0])*256 + TypeConversionUtil.byteToInt(stratfrei[1]);
            int freqde = TypeConversionUtil.byteToInt(stratfred[0])*256 + TypeConversionUtil.byteToInt(stratfred[1]);
            int step = TypeConversionUtil.byteToInt(stepfre[0])*256 + TypeConversionUtil.byteToInt(stepfre[1]);
            BigDecimal freqnew = new BigDecimal((freq * 1000 + freqde)).divide(new BigDecimal(1000),3, BigDecimal.ROUND_HALF_UP);
            String data = TypeConversionUtil.typeConversion(intByReference);
            HashMap<String, Object> hashMap = new HashMap<>();
            hashMap.put("ACSADDR",TypeConversionUtil.byteToInt(devicePara.ACSADDR));
            hashMap.put("ACSDATALEN",TypeConversionUtil.byteToInt(devicePara.ACSDATALEN));
            hashMap.put("ANT",TypeConversionUtil.byteToInt(devicePara.ANT));
            hashMap.put("BAUDRATE",TypeConversionUtil.byteToInt(devicePara.BAUDRATE));
            hashMap.put("BUZZERTIME",TypeConversionUtil.byteToInt(devicePara.BUZZERTIME));
            hashMap.put("CN",TypeConversionUtil.byteToInt(devicePara.CN));
            hashMap.put("DEVICEARRD",TypeConversionUtil.byteToInt(devicePara.DEVICEARRD));
            hashMap.put("FILTERTIME",TypeConversionUtil.byteToInt(devicePara.FILTERTIME));
            hashMap.put("INTERFACE",TypeConversionUtil.byteToInt(devicePara.INTERFACE));
            hashMap.put("INTERNELTIME",TypeConversionUtil.byteToInt(devicePara.INTERNELTIME));
            hashMap.put("INVENTORYAREA",TypeConversionUtil.byteToInt(devicePara.INVENTORYAREA));
            hashMap.put("QVALUE",TypeConversionUtil.byteToInt(devicePara.QVALUE));
            hashMap.put("REGION",TypeConversionUtil.byteToInt(devicePara.REGION));
            hashMap.put("RFIDPOWER",TypeConversionUtil.byteToInt(devicePara.RFIDPOWER));
            hashMap.put("RFIDPRO",TypeConversionUtil.byteToInt(devicePara.RFIDPRO));
            hashMap.put("SESSION",TypeConversionUtil.byteToInt(devicePara.SESSION));
            hashMap.put("STEPFRE",step);
            hashMap.put("STRATFRED",freqde);
            if(freqnew!=null){
                DecimalFormat df = new DecimalFormat( "#,##0.000");
                String format = df.format(freqnew.doubleValue());
                hashMap.put("STRATFREI",format);
            }
            hashMap.put("TRIGGLETIME",TypeConversionUtil.byteToInt(devicePara.TRIGGLETIME));
            hashMap.put("WGSET",TypeConversionUtil.byteToInt(devicePara.WGSET));
            hashMap.put("WORKMODE",TypeConversionUtil.byteToInt(devicePara.WORKMODE));
            hashMap.put("data",data);
            hashMap.put("log",null);
            hashMap.put("msgB",null);
            hashMap.put("res_code",1000);
            return new DataResponse<>(hashMap);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }



    /**
     * Set up power command
     * @param hComm
     * @param power
     * @param reserved
     * @return
     */
    @PostMapping("/SetRFPower")
    public DataResponse SetRFPower(@RequestParam(name = "hComm")int hComm,@RequestParam(name = "power") byte power, @RequestParam(name = "reserved")byte reserved){
        try {
            IntByReference intByReference =  CLibrary.INSTANCE.SetRFPower(hComm, power, reserved);
            String data = TypeConversionUtil.typeConversion(intByReference);
            DataInfo dataInfo = new DataInfo(data,null,null,"1000");
            return new DataResponse<>(dataInfo);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }

    /**
     * Office command
     * @param hComm
     * @param btInvCount
     * @param dwInvParam
     * @return
     */
    @PostMapping("/InventoryContinue")
    public DataResponse InventoryContinue(@RequestParam(name = "hComm")int hComm, @RequestParam(name = "btInvCount")byte btInvCount, @RequestParam(name = "dwInvParam")int dwInvParam){
        try {
            IntByReference intByReference =  CLibrary.INSTANCE.InventoryContinue(hComm,(btInvCount) ,dwInvParam);
            String data = TypeConversionUtil.typeConversion(intByReference);
            DataInfo dataInfo = new DataInfo(data,null,null,"1000");
            return new DataResponse<>(dataInfo);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }


    /**
     * Setting up the equipment parameters command
     * @return
     */
    @PostMapping("/SetDevicePara")
    public DataResponse SetDevicePara(@RequestBody HashMap<String,Object> map){
        try {
            int hComm =Integer.parseInt((String) map.get("hComm")) ;
            DataResponse dataResponse = this.GetDevicePara(map);
            Object data1 = dataResponse.getData();
            DevicePara2 devicePara2 = JSONObject.parseObject(JSON.toJSONBytes(dataResponse.getData()), DevicePara2.class);
            DevicePara.ByReference devicePara = new DevicePara.ByReference();
             CLibrary.INSTANCE.GetDevicePara( hComm, devicePara);
            int freq = devicePara2.getSTRATFREI().intValue();
            int freqde =(int)(devicePara2.getSTRATFREI().floatValue() * 1000 - freq * 1000);
            byte[]  STRATFREI = {(byte) (freq>>8),(byte)(freq&0xff)};
            byte[]  STRATFRED = {(byte) (freqde>>8), (byte)(freqde&0xff)};
            byte[]  STEPFRE = {(byte)((int)devicePara2.getSTEPFRE()>>8), (byte)((int)devicePara2.getSTEPFRE()&0xff)};
            IntByReference intByReference=CLibrary.INSTANCE.SetDevicePara_J(hComm, devicePara.DEVICEARRD, devicePara.RFIDPRO,devicePara.WORKMODE, (byte)128,devicePara.BAUDRATE, devicePara.WGSET, devicePara.ANT,devicePara.REGION,
                    (byte) (freq>>8),(byte)(freq&0xff),
                    (byte) (freqde>>8), (byte)(freqde&0xff),
                    (byte)((int)devicePara2.getSTEPFRE()>>8), (byte)((int)devicePara2.getSTEPFRE()&0xff),
                    devicePara.CN, devicePara.RFIDPOWER, devicePara.INVENTORYAREA,
                    devicePara.QVALUE, devicePara.SESSION, devicePara.ACSADDR,
                    devicePara.ACSDATALEN, devicePara.FILTERTIME, devicePara.TRIGGLETIME,
                    devicePara.BUZZERTIME, devicePara.INTERNELTIME);
            String data = TypeConversionUtil.typeConversion(intByReference);
            return new DataResponse<>(data);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }

    /**
     * The label information
     * @param hComm
     * @param timeout
     * @return
     */
    @PostMapping("/GetTagInfoUHF")
    public  DataResponse GetTagInfo( @RequestParam(name = "hComm")int hComm,  @RequestParam(name = "timeout")int timeout){
            TagInfo.ByReference tagInfo= new TagInfo.ByReference ();
            IntByReference intByReference3 = CLibrary.INSTANCE.GetTagUii(hComm,tagInfo,timeout);
            String code = TypeConversionUtil.conver16HexStr(tagInfo.m_code,12);
            System.out.println(code);
            String data =TypeConversionUtil.typeConversion(intByReference3);
            DataInfo dataInfo = new DataInfo(tagInfo,null,null,"1000");
            return new DataResponse<>(dataInfo);

    }



    /**
     * Stop counting
     * @return
     */
    @PostMapping("/InventoryStop")
    public DataResponse InventoryStop(@RequestBody HashMap<String,Object> map ){
            int hComm =Integer.parseInt((String) map.get("hComm")) ;
            int timeout =(int)map.get("timeout");
            IntByReference intByReference = CLibrary.INSTANCE.InventoryStop(hComm,timeout);
            String data = TypeConversionUtil.typeConversion(intByReference);
            if(StringUtils.isEmpty(data)){
                data=TypeConversionUtil.success;
            }
            uhfPrimeService.stopCounting();
            DataInfo dataInfo = new DataInfo(data,null,null,"1000");
            return new DataResponse<>(dataInfo);
    }

    /**
     * Setting up the card read access parameters
     * @return
     */
    @PostMapping("/Release_Relay")
    public DataResponse Release_Relay(@RequestBody HashMap<String,Object> map ){
        try {
            int hComm =Integer.parseInt((String) map.get("hComm")) ;
            byte time =TypeConversionUtil.intTobyte((int)map.get("time"));
            IntByReference intByReference = CLibrary.INSTANCE.Release_Relay(hComm,new  ByteByReference(time));
            String data = TypeConversionUtil.typeConversion(intByReference);
            if(StringUtils.isEmpty(data)){
                data=TypeConversionUtil.success;
            }
            DataInfo dataInfo = new DataInfo(data,null,null,"1000");
            return new DataResponse<>(dataInfo);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }

    /**
     * Set the relay is closed
     * @return
     */
    @PostMapping("/Close_Relay")
    public DataResponse Close_Relay(@RequestBody HashMap<String,Object> map ){
        try {
            int hComm =Integer.parseInt((String) map.get("hComm")) ;
            byte time =TypeConversionUtil.intTobyte((int)map.get("time"));
            IntByReference intByReference =  CLibrary.INSTANCE.Close_Relay(hComm,new  ByteByReference(time));
            String data = TypeConversionUtil.typeConversion(intByReference);
            if(StringUtils.isEmpty(data)){
                data=TypeConversionUtil.success;
            }
            DataInfo dataInfo = new DataInfo(data,null,null,"1000");
            return new DataResponse<>(dataInfo);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return  new DataResponse(ResultCodeEnum.SYSTEM_ERROR, "Abnormal interface");
    }

    /**
     * Access to available serial port
     */
    @PostMapping("/getSystemPort")
    public void getSystemPort(){
        List<String> systemPort = uhfPrimeService.getSerialPortList();
        System.out.println(JSONObject.toJSON(systemPort));
    }


    /**
     * Start counting
     * @return
     */
    @PostMapping("/StartCounting")
    public DataResponse startCounting(@RequestBody DevicePara2 devicePara2){
        int freq = devicePara2.getSTRATFREI().intValue();
        int freqde =(int)(devicePara2.getSTRATFREI().floatValue() * 1000 - freq * 1000);
        byte[]  STRATFREI = {(byte) (freq>>8),(byte)(freq&0xff)};
        byte[]  STRATFRED = {(byte) (freqde>>8), (byte)(freqde&0xff)};
        byte[]  STEPFRE = {(byte)((int)devicePara2.getSTEPFRE()>>8), (byte)((int)devicePara2.getSTEPFRE()&0xff)};
        DevicePara devicePara = new DevicePara();
        devicePara.setDEVICEARRD(TypeConversionUtil.intTobyte(devicePara2.getDEVICEARRD()));
        devicePara.setRFIDPRO(TypeConversionUtil.intTobyte(devicePara2.getRFIDPRO()));
        devicePara.setWORKMODE(TypeConversionUtil.intTobyte(devicePara2.getWORKMODE()));
        devicePara.setINTERFACE(TypeConversionUtil.intTobyte(devicePara2.getINTERFACE()));
        devicePara.setBAUDRATE(TypeConversionUtil.intTobyte(devicePara2.getBAUDRATE()));
        devicePara.setWGSET(TypeConversionUtil.intTobyte(devicePara2.getWGSET()));
        devicePara.setANT(TypeConversionUtil.intTobyte(devicePara2.getANT()));
        devicePara.setREGION(TypeConversionUtil.intTobyte(devicePara2.getREGION()));
        devicePara.setSTRATFREI(STRATFREI);
        devicePara.setSTRATFRED(STRATFRED);
        devicePara.setSTEPFRE(STEPFRE);
        devicePara.setCN(TypeConversionUtil.intTobyte(devicePara2.getCN()));
        devicePara.setRFIDPOWER(TypeConversionUtil.intTobyte(devicePara2.getRFIDPOWER()));
        devicePara.setINVENTORYAREA(TypeConversionUtil.intTobyte(devicePara2.getINVENTORYAREA()));
        devicePara.setQVALUE(TypeConversionUtil.intTobyte(devicePara2.getQVALUE()));
        devicePara.setSESSION(TypeConversionUtil.intTobyte(devicePara2.getSESSION ()));
        devicePara.setACSADDR(TypeConversionUtil.intTobyte(devicePara2.getACSADDR()));
        devicePara.setACSDATALEN(TypeConversionUtil.intTobyte(devicePara2.getACSDATALEN()));
        devicePara.setFILTERTIME(TypeConversionUtil.intTobyte(devicePara2.getFILTERTIME()));
        devicePara.setTRIGGLETIME(TypeConversionUtil.intTobyte(devicePara2.getTRIGGLETIME()));
        devicePara.setBUZZERTIME(TypeConversionUtil.intTobyte(devicePara2.getBUZZERTIME()));
        devicePara.setINTERNELTIME(TypeConversionUtil.intTobyte(devicePara2.getINTERNELTIME()));
        devicePara.setHComm(devicePara2.getHComm());
        devicePara.setSTRATFREI(STRATFREI);
        devicePara.setSTEPFRE(STEPFRE);
        devicePara.setSTRATFRED(STRATFRED);
        uhfPrimeService.startCounting(devicePara);
        DataInfo dataInfo = new DataInfo(TypeConversionUtil.success,null,null,"1000");
        return new DataResponse<>(dataInfo);
    }

    /**
     * Get the latest label data
     * @return
     */
    @PostMapping("/GetTagInfo")
    public DataResponse getTagInfos(){
        HashMap<String, Object> hashMap = new HashMap<>();
        ArrayList<TagInfoReturn> list = uhfPrimeService.getTagInfos();
        if(!CollectionUtils.isEmpty(list)){
            list.stream().forEach(r ->{
                if(!StringUtils.isEmpty(r.getM_code())){
                    r.setM_code(r.getM_code().replace(","," "));
                }
                if(r.getCounts()!=null && r.getCounts().length>0){
                    StringBuffer stringBuffer = new StringBuffer();
                    for (int i :r.getCounts()) {
                        stringBuffer.append(i+"/");
                    }
                    String m_code =  stringBuffer.toString().substring(0, stringBuffer.toString().length() - 1); ;
                    r.setM_counts(m_code);
                }
            });
        }
        hashMap.put("data",TypeConversionUtil.success);
        hashMap.put("log",null);
        hashMap.put("msgB",null);
        hashMap.put("taginfo",list);
        hashMap.put("res_code",1000);
        return new DataResponse<>(hashMap);
    }


    /**
     * Access to a serial port,
     * @return
     */
    @PostMapping("/getPorts")
    public DataResponse execRootCmd(){
        ArrayList<String> list = uhfPrimeService.execRootCmd("reg query \"HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB\" /s /v FriendlyName");
        HashMap<String, Object> hashMap = new HashMap<>();
        hashMap.put("ports",list);
        hashMap.put("data",TypeConversionUtil.success);
        hashMap.put("log",null);
        hashMap.put("msgB",null);
        hashMap.put("res_code",1000);
        return new DataResponse<>(hashMap);
    }

    /**
     *Stop the thread
     */
    @PostMapping("/stop")
    public void stop(){
        uhfPrimeService.stopCounting();
    }



    /**
     * Initialize the
     * @return
     */
    @PostMapping("/RebootDevice")
    public DataResponse RebootDevice(@RequestParam(name = "hComm")int hComm){
        IntByReference intByReference =  CLibrary.INSTANCE.RebootDevice(hComm);
        String data = TypeConversionUtil.typeConversion(intByReference);
        DataInfo dataInfo = new DataInfo(data,null,null,"1000");
        return new DataResponse<>(dataInfo);
    }

}
