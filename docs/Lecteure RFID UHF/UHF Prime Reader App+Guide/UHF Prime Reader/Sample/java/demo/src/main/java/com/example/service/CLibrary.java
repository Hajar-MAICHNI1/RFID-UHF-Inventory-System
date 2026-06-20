package com.example.service;

import com.example.bean.*;
import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.ByteByReference;
import com.sun.jna.ptr.IntByReference;

public interface CLibrary extends Library {
    CLibrary INSTANCE = (CLibrary) Native.loadLibrary("dll/UHFPrimeReader", CLibrary.class);

    IntByReference OpenDevice(IntByReference hComm, String ComPort, ByteByReference Baudrate);

    IntByReference  OpenNetConnection(IntByReference hComm, String ip, int port,int timeoutMs);

    IntByReference  CloseDevice(int hComm);

    IntByReference  GetDevicePara(int hComm, DevicePara devInfo);

    IntByReference  SetDevicePara(int hComm, DevicePara devInfo);
    IntByReference SetDevicePara_J(int hComm, byte DEVICEARRD, byte RFIDPRO, byte WORKMODE, byte INTERFACE,byte BAUDRATE,  byte WGSET, byte ANT, byte REGION,
                                   byte STRATFREI1,byte STRATFREI2,
                                   byte STRATFRED1, byte STRATFRED2,
                                   byte STEPFRE1, byte STEPFRE2,
                                   byte CN, byte RFIDPOWER, byte INVENTORYAREA,
                                   byte QVALUE, byte SESSION,
                                   byte ACSADDR, byte ACSDATALEN,
                                   byte FILTERTIME, byte TRIGGLETIME,
                                   byte BUZZERTIME, byte INTENERLTIME);

    //IntByReference SetDevicePara_J(int hComm, byte DEVICEARRD, byte RFIDPRO, byte WORKMODE, byte INTERFACE, byte BAUDRATE, byte WGSET, byte ANT, byte REGION, Pointer STRATFREI, Pointer STRATFRED, Pointer STEPFRE, byte CN, byte RFIDPOWER, byte INVENTORYAREA, byte QVALUE, byte SESSION, byte ACSADDR, byte ACSDATALEN, byte FILTERTIME, byte TRIGGLETIME, byte BUZZERTIME, byte INTENERLTIME);


    IntByReference  SetRFPower(int hComm, byte power, byte reserved);

    IntByReference  InventoryContinue(int hComm, byte btInvCount, int dwInvParam);

    IntByReference  GetTagUii(int hComm, TagInfo tag_info, int timeout);

    IntByReference  InventoryStop(int hComm, int timeout);

    IntByReference  Release_Relay(int hComm, ByteByReference time);

    IntByReference  Close_Relay(int hComm, ByteByReference time);

    IntByReference RebootDevice(int hComm);

   // public void xmltest(QueryStructure.ByReference queryInfo);

}