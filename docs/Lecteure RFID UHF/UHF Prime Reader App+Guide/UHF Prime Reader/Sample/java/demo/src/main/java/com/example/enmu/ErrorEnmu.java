package com.example.enmu;

public enum  ErrorEnmu {
    STAT_OK("0x00000000", "STAT_OK"),
    STAT_PORT_HANDLE_ERR("0xffffff01", "STAT_PORT_HANDLE_ERR"),
    STAT_PORT_OPEN_FAILED("0xffffff02", "STAT_PORT_OPEN_FAILED"),
    STAT_DLL_INNER_FAILED("0xffffff03", " STAT_DLL_INNER_FAILED"),
    STAT_CMD_PARAM_ERR("0xffffff04", "STAT_CMD_PARAM_ERR"),
    STAT_CMD_SERIAL_NUM_EXIT("0xffffff05", "STAT_CMD_SERIAL_NUM_EXIT"),
    STAT_CMD_INNER_ERR("0xffffff06", "STAT_CMD_INNER_ERR"),
    STAT_CMD_INVENTORY_STOP("0xffffff07", "STAT_CMD_INVENTORY_STOP"),
    STAT_CMD_TAG_NO_RESP("0xffffff08", "STAT_CMD_TAG_NO_RESP"),
    STAT_CMD_DECODE_TAG_DATA_FAIL("0xffffff09", "STAT_CMD_DECODE_TAG_DATA_FAIL"),
    STAT_CMD_CODE_OVERFLOW("0xffffff0a", "STAT_CMD_CODE_OVERFLOW"),
    STAT_CMD_AUTH_FAIL("0xffffff0b", "STAT_CMD_AUTH_FAIL"),
    STAT_CMD_PWD_ERR("0xffffff0c", "STAT_CMD_PWD_ERR"),
    STAT_CMD_SAM_NO_RESP("0xffffff0d", "STAT_CMD_SAM_NO_RESP"),
    STAT_CMD_SAM_CMD_FAIL("0xffffff0e", "STAT_CMD_SAM_CMD_FAIL"),
    STAT_CMD_RESP_FORMAT_ERR("0xffffff0f", "STAT_CMD_RESP_FORMAT_ERR"),
    STAT_CMD_HAS_MORE_DATA("0xffffff11", "STAT_CMD_HAS_MORE_DATA"),
    STAT_CMD_BUF_OVERFLOW("0xffffff11", "STAT_CMD_BUF_OVERFLOW"),
    STAT_CMD_COMM_TIMEOUT("0xffffff12", "STAT_CMD_COMM_TIMEOUT"),
    STAT_CMD_COMM_WR_FAILED("0xffffff13", "STAT_CMD_COMM_WR_FAILED"),
    STAT_CMD_COMM_RD_FAILED("0xffffff14", "STAT_CMD_COMM_RD_FAILED"),
    STAT_CMD_NOMORE_DATA("0xffffff15", "STAT_CMD_NOMORE_DATA"),
    STAT_DLL_UNCONNECT("0xffffff16", "STAT_DLL_UNCONNECT"),
    STAT_DLL_DISCONNECT("0xffffff17", "STAT_DLL_DISCONNECT"),
    STAT_CMD_RESP_CRC_ERR("0xffffff18", "STAT_CMD_RESP_CRC_ERR"),
    STAT_GB_TAG_LOW_POWER("0xfffff0", "STAT_GB_TAG_LOW_POWER"),
    STAT_GB_TAG_OPR_LIMIT("0xffffff41", "STAT_GB_TAG_OPR_LIMIT"),
    STAT_GB_TAG_MEM_OVF("0xffffff42", "STAT_GB_TAG_MEM_OVF"),
    STAT_GB_TAG_MEM_LCK("0xffffff43", "STAT_GB_TAG_MEM_LCK"),
    STAT_GB_TAG_PWD_ERR("0xffffff44", "STAT_GB_TAG_PWD_ERR"),
    STAT_GB_TAG_AUTH_FAIL("0xffffff45", "STAT_GB_TAG_AUTH_FAIL"),
    STAT_GB_TAG_UNKNW_ERR("0xffffff46", "STAT_GB_TAG_UNKNW_ERR");




    private String code;
    private String name;


    private ErrorEnmu( String code,String name) {
        this.name = name;
        this.code = code;
    }


    public static String getName(String code) {
        for (ErrorEnmu c : ErrorEnmu.values()) {
            String code1 = c.getCode();
            if (c.getCode().equals(code)) {
                return c.name;
            }
        }
        return null;
    }

    public String getName() {
        return name;
    }

    public String getCode() {
        return code;
    }
}
