package com.example.enmu;

public enum ResultCodeEnum {
    SUCCEEDED("ok", 200),
    SYSTEM_ERROR("system exception", 500);

    private int code;
    private String msg;

    private ResultCodeEnum(String msg, int code) {
        this.msg = msg;
        this.code = code;
    }


    public static String getMsg(int code) {
        String result = null;
        for (ResultCodeEnum c : ResultCodeEnum.values()) {
            if (c.getCode() == code) {
                result = c.msg;
                break;
            }
        }
        return result;
    }

    public int getCode() {
        return code;
    }

    public String getMsg() {
        return msg;
    }

}
