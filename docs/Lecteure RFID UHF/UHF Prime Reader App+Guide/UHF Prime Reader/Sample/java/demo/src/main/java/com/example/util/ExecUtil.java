package com.example.util;

import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.TimeUnit;

public class ExecUtil {
    /**
     * Execute system command
     *
     * @param cmd command
     * @param timeOut time out
     * @return the result
     * @throws IOException
     * @throws InterruptedException
     * @author lyrics
     * @since 2020/06/15
     */
    public static String exec(String cmd,int timeOut) throws IOException, InterruptedException {
        Process p = Runtime.getRuntime().exec(cmd);
        boolean res = p.waitFor(timeOut, TimeUnit.SECONDS);
        if(!res) {
            return "Time out";
        }
        InputStream inputStream = p.getInputStream();
        byte[] data = new byte[1024];
        String result = "";
        while(inputStream.read(data) != -1) {
            result += new String(data,"GBK");
        }
        if (result == "") {
            InputStream errorStream = p.getErrorStream();
            while(errorStream.read(data) != -1) {
                result += new String(data,"GBK");
            }
        }
        return result;
    }

    /**
     * Execute system command
     *
     * @param cmd
     * @param timeOut time out
     * @return the result
     * @throws IOException
     * @throws InterruptedException
     * @author lyrics
     * @since 2020/06/15
     */
    public static String exec(String [] cmd ,int timeOut) throws IOException, InterruptedException {
        Process p = Runtime.getRuntime().exec(cmd);
        boolean res = p.waitFor(timeOut, TimeUnit.SECONDS);
        if(!res) {
            return "Time out";
        }
        InputStream inputStream = p.getInputStream();
        byte[] data = new byte[1024];
        String result = "";
        while(inputStream.read(data) != -1) {
            result += new String(data,"GBK");
        }
        if (result == "") {
            InputStream errorStream = p.getErrorStream();
            while(errorStream.read(data) != -1) {
                result += new String(data,"GBK");
            }
        }
        return result;
    }
    public static void main(String [] args) {
        // test 1: ping
        try {
            String res = ExecUtil.exec("reg query \"HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB\" /s /v FriendlyName", 5);
            System.out.println(res);
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

}
