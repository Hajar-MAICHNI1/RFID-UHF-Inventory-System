package com.example.util;

import com.example.enmu.ErrorEnmu;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.IntByReference;

public class TypeConversionUtil {
    public final static  String success="Command executed successfully";
    public static byte[] intToBytes( int value )
    {
        byte[] src = new byte[4];
        src[3] =  (byte) ((value>>24) & 0xFF);
        src[2] =  (byte) ((value>>16) & 0xFF);
        src[1] =  (byte) ((value>>8) & 0xFF);
        src[0] =  (byte) (value & 0xFF);
        return src;
    }

    public static int bytesToInt(byte[] src, int offset) {
        int value;
        value = (int) ((src[offset] & 0xFF)
                | ((src[offset+1] & 0xFF)<<8)
                | ((src[offset+2] & 0xFF)<<16)
                | ((src[offset+3] & 0xFF)<<24));
        return value;
    }


    public static int byteToInt( byte javaReceive){
        int out = javaReceive;
        int expected = javaReceive & 0xff;
        return expected;
    }
    /**
     *
     * @param javaReceive
     */
    public static byte intTobyte( int javaReceive){
        byte out = (byte)javaReceive;
        return out;
    }


    public static byte[] ss( int value )
    {
        byte[] src = new byte[4];
        src[3] =  (byte) ((value>>24) & 0xFF);
        src[2] =  (byte) ((value>>16) & 0xFF);
        src[1] =  (byte) ((value>>8) & 0xFF);
        src[0] =  (byte) (value & 0xFF);
        return src;
    }



    public static String conver16HexStr(byte[] b,int len) {
        StringBuffer result = new StringBuffer();
        for (int i = 0; i < len; i++) {
            if ((b[i] & 0xff) < 0x10)
                result.append("0");
            result.append(Long.toString(b[i] & 0xff, 16)+ ",");
        }
        return result.toString().toUpperCase();
    }

    public static String conver2HexStr(byte[] b) {
        StringBuffer result = new StringBuffer();
        for (int i = 0; i < b.length; i++) {
            result.append(Long.toString(b[i] & 0xff, 2) + ",");
        }
        return result.toString().substring(0, result.length() - 1);
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
