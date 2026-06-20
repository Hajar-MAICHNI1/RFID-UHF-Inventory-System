package com.example.result;

import com.example.enmu.ResultCodeEnum;
import lombok.ToString;


public class DataResponse<T> extends BaseResponse {

    private T data;

    public DataResponse() {
    }

    public DataResponse(ResultCodeEnum code)
    {
        super(code);
    }

    public DataResponse(T data) {
        super(ResultCodeEnum.SUCCEEDED);
        this.data = data;
    }

    public DataResponse(T data, ResultCodeEnum code) {
        super(code);
        this.data = data;
    }

    public DataResponse(ResultCodeEnum code, T data) {
        super(code);
        this.data = data;
    }

    public DataResponse(T data, ResultCodeEnum code, String message) {
        super(code, message);
        this.data = data;
    }

    public T getData() {
        return data;
    }
}
