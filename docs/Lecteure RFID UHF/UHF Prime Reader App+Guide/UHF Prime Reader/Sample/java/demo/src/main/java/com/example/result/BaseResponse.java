package com.example.result;

import com.example.enmu.ResultCodeEnum;
import lombok.ToString;


public class BaseResponse {

    private Integer code;

    private String msg;

    public BaseResponse() {
    }

    public BaseResponse(ResultCodeEnum code) {
        this(code, code.getMsg());
    }

    public BaseResponse(ResultCodeEnum code, String msg) {
        this.code = code.getCode();
        this.msg = msg;
    }

    @Deprecated
    public BaseResponse(Integer code, String msg) {
        this.code = code;
        this.msg = msg;
    }

    public Integer getCode() {
        return code;
    }

    public String getMsg() {
        return msg;
    }

    public static BaseResponse buildSuccess(){
        return new BaseResponse(ResultCodeEnum.SUCCEEDED,"");
    }
}
