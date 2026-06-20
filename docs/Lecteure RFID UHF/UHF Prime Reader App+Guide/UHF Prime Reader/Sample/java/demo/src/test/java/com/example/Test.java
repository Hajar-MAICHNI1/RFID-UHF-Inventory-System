package com.example;

import com.alibaba.fastjson.JSON;
import com.example.bean.DevicePara;
import com.example.bean.DevicePara2;
import com.example.bean.DevicePara3;
import com.example.enmu.ErrorEnmu;
import com.example.result.DataResponse;
import com.example.service.CLibrary;
import com.example.util.TypeConversionUtil;
import com.example.util.UnsignedByte;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.ByteByReference;
import com.sun.jna.ptr.IntByReference;

import java.math.BigDecimal;

public class Test {

    public static void main(String[] args) {
        IntByReference hComm= new IntByReference();
        CLibrary.INSTANCE.OpenDevice(hComm, "COM65", new ByteByReference(new Byte("4")));
//        System.out.println(hComm.getValue());
        IntByReference reference = CLibrary.INSTANCE.RebootDevice(hComm.getValue());
//        System.out.println(reference.getValue());
        DevicePara devicePara = new DevicePara();
        IntByReference reference1 = CLibrary.INSTANCE.GetDevicePara(hComm.getValue(), devicePara);
//        System.out.println(reference1.getValue());
        String s = JSON.toJSONString(devicePara);
        DevicePara3 d2 = JSON.parseObject(s, DevicePara3.class);
       // IntByReference r = CLibrary.INSTANCE.SetDevicePara(hComm.getValue(),d2);

       // System.out.println(r.getValue());
//        byte[] stratfrei = (devicePara.getSTRATFREI());
////        byte[] stratfred =devicePara.getSTRATFRED();
////        byte[] stepfre = devicePara.getSTEPFRE();
////        int freq = TypeConversionUtil.byteToInt(stratfrei[0])*256 + TypeConversionUtil.byteToInt(stratfrei[1]);
////        int freqde = TypeConversionUtil.byteToInt(stratfred[0])*256 + TypeConversionUtil.byteToInt(stratfred[1]);
////        int step = TypeConversionUtil.byteToInt(stepfre[0])*256 + TypeConversionUtil.byteToInt(stepfre[1]);
////        BigDecimal freqnew = new BigDecimal((freq * 1000 + freqde)).divide(new BigDecimal(1000)).setScale(3, BigDecimal.ROUND_HALF_UP);
////
////
////        DevicePara2 devicePara2 = new DevicePara2();
////        devicePara2.setDEVICEARRD(UnsignedByte.toByte(devicePara.getDEVICEARRD()));
////        devicePara2.setRFIDPRO(TypeConversionUtil.byteToInt(devicePara.getRFIDPRO()));
////        devicePara2.setWORKMODE(TypeConversionUtil.byteToInt(devicePara.getWORKMODE()));
////        devicePara2.setBAUDRATE(TypeConversionUtil.byteToInt(devicePara.getBAUDRATE()));
////        devicePara2.setWGSET(TypeConversionUtil.byteToInt(devicePara.getWGSET()));
////        devicePara2.setANT(TypeConversionUtil.byteToInt(devicePara.getANT()));
////        devicePara2.setREGION(TypeConversionUtil.byteToInt(devicePara.getREGION()));
////        devicePara2.setCN(TypeConversionUtil.byteToInt(devicePara.getCN()));
////        devicePara2.setRFIDPOWER(TypeConversionUtil.byteToInt(devicePara.getRFIDPOWER()));
////        devicePara2.setINVENTORYAREA(TypeConversionUtil.byteToInt(devicePara.getINVENTORYAREA()));
////        devicePara2.setQVALUE(TypeConversionUtil.byteToInt(devicePara.getQVALUE()));
////        devicePara2.setSESSION(TypeConversionUtil.byteToInt(devicePara.getSESSION()));
////        devicePara2.setACSADDR(TypeConversionUtil.byteToInt(devicePara.getACSADDR()));
////        devicePara2.setACSDATALEN(TypeConversionUtil.byteToInt(devicePara.getACSDATALEN()));
////        devicePara2.setFILTERTIME(TypeConversionUtil.byteToInt(devicePara.getFILTERTIME()));
////        devicePara2.setTRIGGLETIME(TypeConversionUtil.byteToInt(devicePara.getTRIGGLETIME()));
////        devicePara2.setBUZZERTIME(TypeConversionUtil.byteToInt(devicePara.getBUZZERTIME()));
////        devicePara2.setINTERNELTIME(TypeConversionUtil.byteToInt(devicePara.getINTERNELTIME()));
////        devicePara2.setAddr(TypeConversionUtil.byteToInt(devicePara.getAddr()));
////
////        devicePara2.setSTRATFREI(freqnew);
////        devicePara2.setSTRATFRED(freqde);
////        devicePara2.setSTEPFRE(step);
////        devicePara2.setINTERFACE(TypeConversionUtil.byteToInt(devicePara.getINTERFACE()));
////
////        byte[]  STRATFREI;
////        byte[]  STRATFRED;
////        byte[]  STEPFRE;
////
////        {
////            int freq1 = devicePara2.getSTRATFREI().intValue();
////            int freqde1 = (devicePara2.getSTRATFREI().intValue() * 1000 - freq * 1000);
////            STRATFREI = new byte[]{(byte) (freq1 >> 8), (byte) (freq1 & 0xff)};
////            STRATFRED = new byte[]{(byte) (freqde1 >> 8), (byte) (freqde1 & 0xff)};
////            STEPFRE = new byte[]{(byte) ((int) devicePara2.getSTEPFRE() >> 8), (byte) ((int) devicePara2.getSTEPFRE() & 0xff)};
////
////        }
////
////            DevicePara3.ByReference devicePara3 = new DevicePara3.ByReference();
////        devicePara3.DEVICEARRD=devicePara2.getDEVICEARRD();
////        devicePara3.RFIDPRO=(byte)devicePara2.getRFIDPRO();
//////            byte s=(byte)devicePara2.getWORKMODE();
////        devicePara3.WORKMODE=(byte)devicePara2.getWORKMODE();
////        devicePara3.INTERFACE=(byte) devicePara2.getINTERFACE();
////        devicePara3.BAUDRATE=(byte)devicePara2.getBAUDRATE();
////        devicePara3.WGSET=(byte)devicePara2.getWGSET();
////        devicePara3.ANT=(byte)devicePara2.getANT();
////        devicePara3.REGION=(byte)devicePara2.getREGION();
////        devicePara3.STRATFREI=STRATFREI;
////        devicePara3.STRATFRED=STRATFRED;
////        devicePara3.STEPFRE=STEPFRE;
////        devicePara3.CN=(byte)devicePara2.getCN();
////        devicePara3.RFIDPOWER=(byte)devicePara2.getRFIDPOWER();
////        devicePara3.INVENTORYAREA=(byte)devicePara2.getINVENTORYAREA();
////        devicePara3.QVALUE=(byte)devicePara2.getQVALUE();
////        devicePara3.SESSION=(byte)devicePara2.getSESSION();
////        devicePara3.ACSADDR=(byte)devicePara2.getACSADDR();
////        devicePara3.ACSDATALEN=(byte)devicePara2.getACSDATALEN();
////        devicePara3.FILTERTIME=(byte)devicePara2.getFILTERTIME();
////        devicePara3.TRIGGLETIME=(byte)devicePara2.getTRIGGLETIME();
////        devicePara3.BUZZERTIME=(byte)devicePara2.getBUZZERTIME();
////        devicePara3.INTERNELTIME=(byte)devicePara2.getINTERNELTIME();
////        devicePara3.Addr=(byte)devicePara2.getAddr();
////
////        IntByReference reference = CLibrary.INSTANCE.SetDevicePara(hComm.getValue(), devicePara3);
////        String data = typeConversion(reference);
////        System.out.println(data);
    }

    public static short bytes2short(byte[] bytes) {
        return  (short) ((0xff & bytes[1]) | (0xff00 & (bytes[0] << 8)));
    }

    public static byte[] short2bytes(short data) {
        byte[] bytes = new byte[2];
        bytes[1] = (byte) (data & 0xff);
        bytes[0] = (byte) ((data & 0xff00) >> 8);
        return bytes;
    }

    public static String typeConversion(IntByReference intByReference){
        if(intByReference!=null){
            Pointer pointer = intByReference.getPointer();
            if(pointer!=null && pointer.toString().contains("native@")){
                String s= pointer.toString().split("native@")[1];
                String name = ErrorEnmu.getName(s);
                return name;
            }
        }
        return null;
    }

}
