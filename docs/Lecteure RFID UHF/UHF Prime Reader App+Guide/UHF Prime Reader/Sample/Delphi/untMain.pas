unit untMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, DBGridEhGrouping, ToolCtrlsEh, DBGridEhToolCtrls, DynVarsEh,
  EhLibVCL, GridsEh, DBAxisGridsEh, DBGridEh, System.Actions, Vcl.ActnList,
  TypInfo, System.Generics.Defaults, Data.DB, MemTableDataEh, MemTableEh,
  Vcl.ComCtrls, System.Win.Registry, RzListVw;

type
  TagInfo = record
    m_no: Word;       //标签序号
    m_rssi: SHORT;     //RSSI，单位：0.1dBm
    m_ant: Byte;         //天线索引
    m_channel: Byte;   // 信道
    m_crc: array[0..1] of Byte;   //CRC
    m_pc: array[0..1] of Byte;   //标签的PC或编码长度+编码头数据
    m_len: Byte;                    // code中有效数据的长度
    m_code: array[0..254] of Byte;   //标签的响应数据，长度255个byte
  end;

  PTagInfo = ^TagInfo;

  TTagItem = class(TObject)
  public
    m_no: Word;       //标签序号
    m_rssi: SHORT;     //RSSI，单位：0.1dBm
    m_ant: Byte;         //天线索引   天线接口序号
    m_channel: Byte;   // 信道
    m_crc: array[0..1] of Byte;   //CRC
    m_pc: array[0..1] of Byte;   //标签的PC或编码长度+编码头数据
    m_len: Byte;                    // code中有效数据的长度
    m_code: array of Byte;   //标签的响应数据，长度255个byte
    procedure Init(tagInfo: TagInfo);
  published
    destructor Destroy;
  end;

  DeviceParameter = record
    DEVICEARRD: byte;
    RFIDPRO: byte;
    WORKMODE: byte;
    INTERFACE2: byte;
    BAUDRATE: byte;
    WGSET: byte;
    ANT: byte;
    REGION: byte;
    STRATFREI: Word;
    STRATFRED: Word;
    STEPFRE: Word;
    CN: byte;
    RFIDPOWER: byte;
    INVENTORYAREA: byte;
    QVALUE: byte;
    SESSION: byte;
    ACSADDR: byte;
    ACSDATALEN: byte;
    FILTERTIME: byte;
    TRIGGLETIME: byte;
    BUZZERTIME: byte;
    INTERNELTIME: byte;
  end;

  PDeviceParameter = ^DeviceParameter;

  ChannelRegion = (Custom, USA, Korea, Europe, Japan, Malaysia, Europe3, China_1, China_2);

  ChannelItem = class(TObject)
  public
    Freq: Double;
    procedure Init(p_Freq: Double);
  end;

  ChannelRegionItem = class(TObject)
  public
    m_value: ChannelRegion;
    m_fFreqStart: Double;
    m_iFreqStep: Integer;
    m_iFreqCount: Integer;
    procedure Init(value: ChannelRegion; FreqStart: Double; FreqStep: Integer; FreqCount: Integer);
  end;

  ChannelCount = class(TObject)
  public
    Count: Integer;
    Region: ChannelRegionItem;
    procedure Init(p_region: ChannelRegionItem; p_count: Integer);
  end;

  TArrayOfChannelCount = array of ChannelCount; //字符串数组

  TfmMain = class(TForm)
    GroupBox1: TGroupBox;
    GroupBox3: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    cmbComportList: TComboBox;
    cmbBaudList: TComboBox;
    Button1: TButton;
    Button2: TButton;
    GroupBox2: TGroupBox;
    Label3: TLabel;
    Label4: TLabel;
    Button3: TButton;
    Button4: TButton;
    txbIPAddr: TEdit;
    txbPort: TEdit;
    Button5: TButton;
    Button6: TButton;
    Label5: TLabel;
    Label6: TLabel;
    cmbTxPower: TComboBox;
    cmbWorkmode: TComboBox;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    Button10: TButton;
    Label7: TLabel;
    cmbRegion: TComboBox;
    Button11: TButton;
    Button12: TButton;
    Label8: TLabel;
    cmbFreqStart: TComboBox;
    cmbFreqEnd: TComboBox;
    Label9: TLabel;
    Button13: TButton;
    Button14: TButton;
    actList: TActionList;
    actSportOpen: TAction;
    actSportClose: TAction;
    actNetConnect: TAction;
    actNetDiscount: TAction;
    actGetTxPower: TAction;
    actSetTxPower: TAction;
    actGetWorkMode: TAction;
    actSetWorkMode: TAction;
    actClose_Realy: TAction;
    actRelease_Realy: TAction;
    actGetFreq: TAction;
    actSetFreq: TAction;
    actStart: TAction;
    actStop: TAction;
    GroupBox4: TGroupBox;
    mmoLogs: TMemo;
    ds_list: TDataSource;
    mt_list: TMemTableEh;
    mt_listcolNum: TStringField;
    mt_listcolCode: TStringField;
    mt_listcolCodeLen: TStringField;
    mt_listcolCount: TStringField;
    mt_listcolRssi: TStringField;
    mt_listcolCw: TStringField;
    Button15: TButton;
    mt_listant: TIntegerField;
    mt_listant1: TIntegerField;
    mt_listant2: TIntegerField;
    mt_listant3: TIntegerField;
    mt_listant4: TIntegerField;
    lstView: TRzListView;
    Button16: TButton;
    actClearData: TAction;
    procedure actSportOpenExecute(Sender: TObject);
    procedure actSportCloseExecute(Sender: TObject);
    procedure actNetConnectExecute(Sender: TObject);
    procedure actNetConnectUpdate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure actSportOpenUpdate(Sender: TObject);
    procedure actSportCloseUpdate(Sender: TObject);
    procedure actNetDiscountUpdate(Sender: TObject);
    procedure actNetDiscountExecute(Sender: TObject);
    procedure actGetTxPowerExecute(Sender: TObject);
    procedure actGetTxPowerUpdate(Sender: TObject);
    procedure actSetTxPowerExecute(Sender: TObject);
    procedure actSetTxPowerUpdate(Sender: TObject);
    procedure actGetWorkModeExecute(Sender: TObject);
    procedure actGetWorkModeUpdate(Sender: TObject);
    procedure actSetWorkModeExecute(Sender: TObject);
    procedure actSetWorkModeUpdate(Sender: TObject);
    procedure actClose_RealyExecute(Sender: TObject);
    procedure actClose_RealyUpdate(Sender: TObject);
    procedure actRelease_RealyUpdate(Sender: TObject);
    procedure actRelease_RealyExecute(Sender: TObject);
    procedure actGetFreqExecute(Sender: TObject);
    procedure actGetFreqUpdate(Sender: TObject);
    procedure actSetFreqExecute(Sender: TObject);
    procedure actSetFreqUpdate(Sender: TObject);
    procedure cmbRegionChange(Sender: TObject);
    procedure actStartExecute(Sender: TObject);
    procedure actStartUpdate(Sender: TObject);
    procedure actStopUpdate(Sender: TObject);
    procedure actStopExecute(Sender: TObject);
    procedure Button15Click(Sender: TObject);
    procedure actClearDataExecute(Sender: TObject);
  private
    { Private declarations }
    gDevPara: DeviceParameter;
    gConnected: Boolean;
    gHandlePort: IntPtr;    //句柄
    gSTRATFREI: Integer;
    gSTRATFRED: Integer;
    gSTEPFRE: Integer;
    s_usStopInventoryTimeout: USHORT;  // 停止盘点等待的时间
    m_btInvType: UINT; // 盘点类型
    m_uiInvParam: UINT;  //盘点类型参数

    gStopInventory: Boolean;   //是否停止盘点

    procedure GetChannelItems(region: ChannelRegionItem);
    procedure GetChannelCounts(region: ChannelRegionItem);
    function ConvertIntToXiaoDuan(p_val: Integer): Integer;   //转为小端
    function ConvertXiaoDuanToInt(p_val: Integer): Integer;
    function GetDeviceParameter: Integer;
    procedure SetDeviceParameter;
    procedure InventoryThread;
    procedure StartThread;
    function Byte2Hex(arrByte: array of Byte; len: Byte): string;
    function ConvertResult(p_val: Word): Word;
    procedure GetPortList;
    procedure InitData;
    procedure LoadFreq;
    procedure ShowRunLog(p_log: string);
    function GetErrorMessage(msg_code: Integer): string;
  public
    { Public declarations }
  end;

  //public static extern int OpenDevice(out IntPtr m_hPort, string strComPort, byte Baudrate);
function OpenDevice(m_hPort: PHandle; strComPort: PAnsiChar; Baudrate: Byte): Integer; stdcall; external 'UHFPrimeReader.dll';

function CloseDevice(m_hPort: IntPtr): Integer; stdcall; external 'UHFPrimeReader.dll';

function GetDevicePara(m_hPort: IntPtr; devInfo: PDeviceParameter): Integer; stdcall; external 'UHFPrimeReader.dll';

function SetDevicePara(m_hPort: IntPtr; devInfo: DeviceParameter): Integer; stdcall; external 'UHFPrimeReader.dll';

function OpenNetConnection(m_hPort: PHandle; ip: PAnsiChar; port: ushort; timeoutMs: uint): Integer; stdcall; external 'UHFPrimeReader.dll';

function Close_Relay(m_hPort: IntPtr; time: byte): Integer; stdcall; external 'UHFPrimeReader.dll';

function Release_Relay(m_hPort: IntPtr; time: byte): Integer; stdcall; external 'UHFPrimeReader.dll';

//结束库存
function InventoryStop(hComm: IntPtr; timeout: Word): Integer; stdcall; external 'UHFPrimeReader.dll';

//开始库存
function InventoryContinue(hComm: IntPtr; invCount: byte; invParam: UINT): Integer; stdcall; external 'UHFPrimeReader.dll';

function GetTagUii(hComm: IntPtr; tag_info: PTagInfo; timeout: ushort): Integer; stdcall; external 'UHFPrimeReader.dll';
//public static extern int GetTagUii(IntPtr hComm, out TagInfo tag_info, ushort timeout);

var
  fmMain: TfmMain;
  USARegion: ChannelRegionItem;
  KoreaRegion: ChannelRegionItem;
  EuropeRegion: ChannelRegionItem;
  JapanRegion: ChannelRegionItem;
  MalaysiaRegion: ChannelRegionItem;
  Europe3Region: ChannelRegionItem;
  China1Region: ChannelRegionItem;
  CustomRegion: ChannelRegionItem;
  China2Region: ChannelRegionItem;
  Options: array[0..8] of ChannelRegionItem;
  OptionsStandard: array[0..8] of ChannelRegionItem;

implementation

{$R *.dfm}

{ ChannelRegionItem }

procedure ChannelRegionItem.Init(value: ChannelRegion; FreqStart: Double; FreqStep, FreqCount: Integer);
begin
  m_value := value;
  m_fFreqStart := FreqStart;
  m_iFreqStep := FreqStep;
  m_iFreqCount := FreqCount;
end;


{ ChannelCount }

procedure ChannelCount.Init(p_region: ChannelRegionItem; p_count: Integer);
begin
  Region := p_region;
  Count := p_count;
end;

procedure TfmMain.FormCreate(Sender: TObject);
begin
  GetPortList;
  cmbBaudList.ItemIndex := 4;

  gStopInventory := true;
  gConnected := False;   // True; //

  USARegion := ChannelRegionItem.Create;
  USARegion.Init(ChannelRegion.USA, 902.750, 500, 50);

  KoreaRegion := ChannelRegionItem.Create;
  KoreaRegion.Init(ChannelRegion.Korea, 917.100, 200, 32);

  EuropeRegion := ChannelRegionItem.Create;
  EuropeRegion.Init(ChannelRegion.Europe, 865.100, 200, 15);

  JapanRegion := ChannelRegionItem.Create;
  JapanRegion.Init(ChannelRegion.Japan, 952.200, 200, 8);

  MalaysiaRegion := ChannelRegionItem.Create;
  MalaysiaRegion.Init(ChannelRegion.Malaysia, 919.500, 500, 7);

  Europe3Region := ChannelRegionItem.Create;
  Europe3Region.Init(ChannelRegion.Europe3, 865.700, 600, 4);

  China1Region := ChannelRegionItem.Create;
  China1Region.Init(ChannelRegion.China_1, 840.125, 250, 20);

  CustomRegion := ChannelRegionItem.Create;
  CustomRegion.Init(ChannelRegion.Custom, 0, 0, 0);

  China2Region := ChannelRegionItem.Create;
  China2Region.Init(ChannelRegion.China_2, 920.125, 250, 20);

  Options[0] := USARegion;
  Options[1] := KoreaRegion;
  Options[2] := EuropeRegion;
  Options[3] := JapanRegion;
  Options[4] := MalaysiaRegion;
  Options[5] := Europe3Region;
  Options[6] := China1Region;
  Options[7] := China2Region;
  Options[8] := CustomRegion;

  OptionsStandard[0] := USARegion;
  OptionsStandard[1] := KoreaRegion;
  OptionsStandard[2] := EuropeRegion;
  OptionsStandard[3] := JapanRegion;
  OptionsStandard[4] := MalaysiaRegion;
  OptionsStandard[5] := Europe3Region;
  OptionsStandard[6] := China1Region;
  OptionsStandard[7] := China2Region;
  OptionsStandard[8] := CustomRegion;

  s_usStopInventoryTimeout := 10000;  // 停止盘点等待的时间
  m_btInvType := 0; // 盘点类型
  m_uiInvParam := 0;  //盘点类型参数
end;

procedure TfmMain.GetPortList;
var
  reg: TRegistry;
  ComList: TStringList;
  i: Integer;
begin
  ComList := TStringList.Create;
  reg := TRegistry.Create;
  cmbComportList.Clear;
  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    if reg.OpenKey('HARDWARE\DEVICEMAP\SERIALCOMM', false) then
    begin
      //ShowMessage('提示1');
      reg.GetValueNames(ComList);
      //ShowMessage('列表:' + ComList.Text);
      for i := 0 to ComList.Count - 1 do
        cmbComportList.Items.Add(reg.ReadString(ComList[i]));
    end;
//    cmbComportList.Items.Add('COM1');
//    cmbComportList.Items.Add('COM2');
//    cmbComportList.Items.Add('COM3');
//    cmbComportList.Items.Add('COM4');
//    cmbComportList.Items.Add('COM5');
    cmbComportList.ItemIndex := 0;
  finally
    ComList.Free;
    reg.Free;
  end;
end;

procedure TfmMain.InitData;
var
  iVal: Integer;
begin
//自动取一次数据
  iVal := GetDevicePara(gHandlePort, @gDevPara);

  if iVal = 0 then
  begin
    GetDeviceParameter;

    //绑定控件
    cmbTxPower.ItemIndex := cmbTxPower.Items.IndexOf(gDevPara.RFIDPOWER.ToString());
    cmbWorkmode.ItemIndex := gDevPara.WORKMODE;

  //显示freq部分
    LoadFreq;
  end
  else
  begin
    iVal := CloseDevice(gHandlePort);
    gConnected := False;
    Application.MessageBox(PWideChar('read parameter fail:' + GetErrorMessage(iVal)), 'message', MB_OK + MB_ICONINFORMATION);
  end;
end;
{ ChannelItem }

procedure ChannelItem.Init(p_Freq: Double);
begin
  freq := p_Freq;
end;

{$REGION 'Connect Comport'}

procedure TfmMain.actSportCloseExecute(Sender: TObject);
var
  iVal: Integer;
begin
  if (gHandlePort > 0) then
  begin
    try
      iVal := CloseDevice(gHandlePort);
      ShowRunLog('comport close');
    except
    end;
    gConnected := False;
    gHandlePort := 0;
  end;
end;

procedure TfmMain.actSportCloseUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

procedure TfmMain.actSportOpenExecute(Sender: TObject);
var
  com, bt: string;
  ival: Integer;
begin
  com := cmbComportList.Text;
  bt := cmbBaudList.Text;
  gHandlePort := 0;
  //设置通讯波特率0x00：9600； 0x01：19200；0x02：38400；0x03：57600；0x04：115200（默认）；
  if bt = '9600' then
    ival := OpenDevice(@gHandlePort, PAnsiChar(AnsiString(com)), $00)
  else if bt = '19200' then
    ival := OpenDevice(@gHandlePort, PAnsiChar(AnsiString(com)), $01)
  else if bt = '38400' then
    ival := OpenDevice(@gHandlePort, PAnsiChar(AnsiString(com)), $02)
  else if bt = '57600' then
    ival := OpenDevice(@gHandlePort, PAnsiChar(AnsiString(com)), $03)
  else if bt = '115200' then
    ival := OpenDevice(@gHandlePort, PAnsiChar(AnsiString(com)), $04);

  if ival = 0 then
  begin
    gConnected := True;
    ShowRunLog('The comport is opened successfully, the port number:' + com);

    //自动取一次数据
    InitData;
  end
  else
  begin
    gConnected := False;
    Application.MessageBox(PWideChar('open comport fail:' + GetErrorMessage(ival)), 'message', MB_OK + MB_ICONINFORMATION);
  end;
end;

procedure TfmMain.actSportOpenUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := (not gConnected) and
    (cmbBaudList.ItemIndex > -1) and (cmbComportList.ItemIndex > -1);
end;

{$ENDREGION}

{$REGION 'Net Connect'}

procedure TfmMain.actNetConnectExecute(Sender: TObject);
var
  ip: string;
  port: Word;
  ival: Integer;
begin
  //
  ip := Trim(txbIPAddr.Text);
  port := StrToInt(txbPort.Text);

  ival := OpenNetConnection(@gHandlePort, PAnsiChar(AnsiString(ip)), port, 10000);

  if ival = 0 then
  begin
    gConnected := True;
    ShowRunLog('open success，IP address:' + ip + ',' + port.ToString);

    //自动取一次数据
    InitData;

    //Application.MessageBox('Net连接成功!', '提示', MB_OK + MB_ICONINFORMATION);
  end
  else
  begin
    gConnected := False;
    Application.MessageBox(PWideChar('connect fail:' + GetErrorMessage(ival)), 'message', MB_OK + MB_ICONINFORMATION);
  end;
end;

procedure TfmMain.actNetConnectUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := not gConnected;
end;

procedure TfmMain.actNetDiscountExecute(Sender: TObject);
var
  iVal: Integer;
begin
  if (gHandlePort > 0) then
  begin
    try
      iVal := CloseDevice(gHandlePort);
      ShowRunLog('network discount');
    except
    end;
    gConnected := False;
    gHandlePort := 0;
  end;
end;

procedure TfmMain.actNetDiscountUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;


{$ENDREGION}

{$REGION 'RfPower(dbm)'}

procedure TfmMain.actGetTxPowerExecute(Sender: TObject);
var
  iVal: Integer;
begin
  iVal := GetDevicePara(gHandlePort, @gDevPara);
  GetDeviceParameter;
  if (iVal = 0) then
  begin
    cmbTxPower.ItemIndex := cmbTxPower.Items.IndexOf(gDevPara.RFIDPOWER.ToString());
    ShowRunLog('Get device RfPower');
  end
  else
    Application.MessageBox(PWideChar('Get Parameter Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
end;

procedure TfmMain.actGetTxPowerUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

procedure TfmMain.actSetTxPowerExecute(Sender: TObject);
var
  iVal: Integer;
begin
  gDevPara.RFIDPOWER := Byte(StrToInt(cmbTxPower.Text));
  SetDeviceParameter;
  iVal := SetDevicePara(gHandlePort, gDevPara);
  if (iVal = 0) then
  begin
    ShowRunLog('Set device RfPower');
    //Application.MessageBox('参数设置成功', '提示', MB_OK + MB_ICONINFORMATION);
  end
  else
    Application.MessageBox(PWideChar('Set Parameter Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
end;

procedure TfmMain.actSetTxPowerUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

{$ENDREGION}

{$REGION 'WorkMode'}

procedure TfmMain.actGetWorkModeExecute(Sender: TObject);
var
  iVal: Integer;
begin
  iVal := GetDevicePara(gHandlePort, @gDevPara);
  GetDeviceParameter;
  if (iVal = 0) then
  begin
    cmbWorkmode.ItemIndex := gDevPara.WORKMODE;
    ShowRunLog('Get device Workmode');
  end
  else
    Application.MessageBox(PWideChar('Get Parameter Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
end;

procedure TfmMain.actGetWorkModeUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

procedure TfmMain.actSetWorkModeExecute(Sender: TObject);
var
  iVal: Integer;
begin
  gDevPara.WORKMODE := Byte(cmbWorkmode.ItemIndex);
  SetDeviceParameter;
  iVal := SetDevicePara(gHandlePort, gDevPara);
  if (iVal = 0) then
  begin
    ShowRunLog('Set device Workmode');
    //Application.MessageBox('参数设置成功', '提示', MB_OK + MB_ICONINFORMATION);
  end
  else
    Application.MessageBox(PWideChar('Set Parameter Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
end;

procedure TfmMain.actSetWorkModeUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

{$ENDREGION}

{$REGION 'Close Realy'}

procedure TfmMain.actClearDataExecute(Sender: TObject);
begin
  //
  mt_list.EmptyTable;
  lstView.Clear;
end;

procedure TfmMain.actClose_RealyExecute(Sender: TObject);
var
  iVal: Integer;
begin
  //设置继电器闭合
  iVal := Close_Relay(gHandlePort, 0);
  if (iVal = 0) then
  begin
    ShowRunLog('Set device Close_Realy');
    //Application.MessageBox('设置成功', '提示', MB_OK + MB_ICONINFORMATION);
  end
  else
    Application.MessageBox(PWideChar('Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
end;

procedure TfmMain.actClose_RealyUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

procedure TfmMain.actRelease_RealyExecute(Sender: TObject);
var
  iVal: Integer;
begin
  //设置读卡权限参数
  iVal := Release_Relay(gHandlePort, 0);
  if (iVal = 0) then
  begin
    ShowRunLog('Set device Release_Realy');
    //Application.MessageBox('设置成功', '提示', MB_OK + MB_ICONINFORMATION);
  end
  else
    Application.MessageBox(PWideChar('Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
end;

procedure TfmMain.actRelease_RealyUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

{$ENDREGION}

{$REGION 'Freq'}

procedure TfmMain.cmbRegionChange(Sender: TObject);
var
  region: ChannelRegionItem;
  I: Integer;
begin
  //
  if cmbRegion.ItemIndex = -1 then
    Exit;

  for I := 0 to Length(OptionsStandard) - 1 do
  begin
    region := OptionsStandard[I];
    if GetEnumName(TypeInfo(ChannelRegion), Ord(region.m_value)) = cmbRegion.Text then
    begin
      Break;
    end;
  end;

  if region.m_value = Custom then
  begin
    cmbFreqStart.Style := csDropDown;
    cmbFreqEnd.Style := csDropDown;
  end
  else
  begin
    cmbFreqStart.Style := csDropDownList;
    cmbFreqEnd.Style := csDropDownList;

    GetChannelItems(region);

    GetChannelCounts(region);
  end;
end;

procedure TfmMain.actGetFreqExecute(Sender: TObject);
var
  iVal: Integer;
begin
  iVal := GetDevicePara(gHandlePort, @gDevPara);
  GetDeviceParameter;
  if (iVal = 0) then
  begin
    begin
      LoadFreq;
      ShowRunLog('Get device Freq');
    end;
  end
  else
    Application.MessageBox(PWideChar('Get Parameter Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
end;

procedure TfmMain.actGetFreqUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

procedure TfmMain.actSetFreqExecute(Sender: TObject);
var
  iVal: Integer;
  region: ChannelRegionItem;
  I, count2, step: Integer;
  freq2, f_endfreq, I2: Double;
begin
  gDevPara.Region := Byte(cmbRegion.ItemIndex);

  for I := 0 to Length(OptionsStandard) - 1 do
  begin
    region := OptionsStandard[I];
    if GetEnumName(TypeInfo(ChannelRegion), Ord(region.m_value)) = cmbRegion.Text then
    begin
      Break;
    end;
  end;

  if (region.m_value = ChannelRegion.Custom) then          // custom
  begin
    freq2 := StrToFloat(cmbFreqStart.Text);
    f_endfreq := StrToFloat(cmbFreqEnd.Text);
    step := 500;
    count2 := Trunc((f_endfreq - freq2) / step);
  end
  else
  begin
    freq2 := StrToFloat(cmbFreqStart.Text);
    count2 := cmbFreqEnd.ItemIndex - cmbFreqStart.ItemIndex + 1;
    f_endfreq := freq2 + (region.m_iFreqStep) * count2;
  end;

  I2 := freq2 * 1000; // 不能动

  gSTRATFREI := Trunc(freq2);
  gSTRATFRED := Trunc(I2 - Trunc(freq2) * 1000);       // 精度问题，浮点数运算会丢失
  gSTEPFRE := region.m_iFreqStep;
  gDevPara.CN := Byte(count2);

  SetDeviceParameter;
  iVal := SetDevicePara(gHandlePort, gDevPara);

  if (iVal = 0) then
  begin
    ShowRunLog('Set device Freq');
    //Application.MessageBox('参数设置成功', '提示', MB_OK + MB_ICONINFORMATION);
  end
  else
    Application.MessageBox(PWideChar('Set Parameter Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
end;

procedure TfmMain.actSetFreqUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected;
end;

procedure TfmMain.LoadFreq;
var
  iVal, I: Integer;
  Region, Count: Byte;
  StartFreq, StepFreq: Double;
begin
  Region := gDevPara.Region;
  StartFreq := gDevPara.STRATFREI + gDevPara.STRATFRED / 1000.0;
  StepFreq := gDevPara.STEPFRE;
  Count := gDevPara.CN;

  cmbRegion.ItemIndex := Region;
  cmbRegionChange(nil);

  for I := 0 to cmbFreqStart.Items.Count - 1 do
  begin
    if Abs(StrToFloat(cmbFreqStart.Items[I]) - StartFreq) < 0.01 then
    begin
      cmbFreqStart.ItemIndex := I;
      Break;
    end;
  end;

  for I := 0 to cmbFreqEnd.Items.Count - 1 do
  begin
    if Abs(StrToFloat(cmbFreqEnd.Items[I]) - Count) < 0.01 then
    begin
      cmbFreqEnd.ItemIndex := I;
      Break;
    end;
  end;
end;

{$ENDREGION}

{$REGION 'Start/Stop'}

procedure TfmMain.actStartExecute(Sender: TObject);
var
  iVal: Integer;
  info: TagInfo;
begin
//
  //先保存参数
  gDevPara.WORKMODE := Byte(cmbWorkmode.ItemIndex);
  SetDeviceParameter;
  iVal := SetDevicePara(gHandlePort, gDevPara);

  if (iVal <> 0) then
  begin
    Application.MessageBox(PWideChar('Set Parameter Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
    Exit;
  end;

  //mmoLogs.Lines.Add('cmbWorkmode结果：' + cmbWorkmode.ItemIndex.ToString);

  if (cmbWorkmode.ItemIndex = 0) then
  begin
    //应答模式,需要下发数据
    //发送读取指令
    Sleep(300);
    m_btInvType := 0;
    m_uiInvParam := 0;
    iVal := InventoryContinue(gHandlePort, Byte(m_btInvType), m_uiInvParam);   // start inventory
    //mmoLogs.Lines.Add('InventoryContinue结果：' + iVal.ToString);
    if (iVal <> 0) then
    begin
      Application.MessageBox(PWideChar('Start Error:' + GetErrorMessage(iVal)), '提示', MB_OK + MB_ICONINFORMATION);
      Exit;
    end;

    ShowRunLog('Start inventory');
    //启动线程读取
    InventoryThread;

//    Sleep(2000);
//    iVal := GetTagUii(gHandlePort, @info, 1000);
//
//    mmoLogs.Lines.Add('GetTagUii结果：' + iVal.ToString);
//    exit;

    gStopInventory := False;
  end
  else
  begin
    //主动模式
    //启动线程读取
    ShowRunLog('Start inventory');
    InventoryThread;

    gStopInventory := False;
  end;
end;

procedure TfmMain.actStartUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected and gStopInventory;
end;

procedure TfmMain.actStopExecute(Sender: TObject);
var
  iVal: Integer;
begin
  gStopInventory := True;

  ShowRunLog('Stop inventory');
  iVal := InventoryStop(gHandlePort, 2000);
end;

procedure TfmMain.actStopUpdate(Sender: TObject);
begin
  (TAction(Sender)).Enabled := gConnected and (not gStopInventory);
end;

procedure TfmMain.InventoryThread;
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      //Sleep(1000);
      StartThread;
    end //此处无分号
    ).Start;
end;

procedure TfmMain.StartThread;
var
  item: TTagItem;
  info: TagInfo;
  code: string;
  ant: Integer;
  val: Integer;
  cnt: Integer;
  lvitem: TListItem;
begin
  try
    cnt := 0;
    mt_list.EmptyTable;
    while not gStopInventory do
    begin
      //调用dll
      //mmoLogs.Lines.Add('GetTagUii start');

      val := GetTagUii(gHandlePort, @info, 1000);

      if (val = -238) or (val = -241) or (val = -236) then
      begin
        //actStop.Execute;
        //ShowMessage('Waiting for reader response timed out');
        //Break;
        continue;
      end;
      //mmoLogs.Lines.Add('GetTagUii end,' + val.ToString);
      //没有数据的情况
      if (val = -249) then
        continue;

        //不成功，继续读取
      if val <> 0 then
        continue;

      // TagInfo==> TTagItem
      item := TTagItem.Create;
      item.Init(info);

      if (item.m_ant = 0) or (item.m_ant > 4) then
        continue;

      //mmoLogs.Lines.Add('GetTagUii 提示1,');
      //接收的数据
      code := Trim(Byte2Hex(item.m_code, item.m_len));
      //mmoLogs.Lines.Add('GetTagUii 提示2,');
      Inc(cnt);

      try
        //mt_list.DisableControls;

        try
        //根据数据判断记录是否存在
          if (mt_list.Locate('Code', code, [loCaseInsensitive])) then
          begin
          //mmoLogs.Lines.Add('GetTagUii 找到：' + code);
            mt_list.Edit;
          end
          else
          begin
            mt_list.Append;
            mt_list.FieldByName('Code').AsString := code;
            mt_list.FieldByName('ant1').AsInteger := 0;
            mt_list.FieldByName('ant2').AsInteger := 0;
            mt_list.FieldByName('ant3').AsInteger := 0;
            mt_list.FieldByName('ant4').AsInteger := 0;
            mt_list.FieldByName('Num').AsString := (mt_list.RecordCount + 1).ToString;
          end;

        //天线计数
          if item.m_ant = 1 then
            mt_list.FieldByName('ant1').AsInteger := mt_list.FieldByName('ant1').AsInteger + 1
          else if item.m_ant = 2 then
            mt_list.FieldByName('ant2').AsInteger := mt_list.FieldByName('ant2').AsInteger + 1
          else if item.m_ant = 3 then
            mt_list.FieldByName('ant3').AsInteger := mt_list.FieldByName('ant3').AsInteger + 1
          else if item.m_ant = 4 then
            mt_list.FieldByName('ant4').AsInteger := mt_list.FieldByName('ant4').AsInteger + 1;

        //纪录
          mt_list.FieldByName('CodeLen').AsString := item.m_len.ToString;
          mt_list.FieldByName('Count').AsString := mt_list.FieldByName('ant1').AsString +   //  //获取被盘点到的次数
            '/' + mt_list.FieldByName('ant2').AsString +  //
            '/' + mt_list.FieldByName('ant3').AsString +   //
            '/' + mt_list.FieldByName('ant4').AsString;
          mt_list.FieldByName('Rssi').AsString := (0 - ConvertResult(item.m_rssi) / 10).ToString;
          mt_list.FieldByName('Cw').AsString := item.m_channel.ToString;
          mt_list.Post;

          mt_list.First;
          lstView.Clear;
          while not mt_list.Eof do
          begin
            with lstView.Items.Add do
            begin
              SubItems.Add(mt_list.FieldByName('Num').AsString);
              SubItems.Add(mt_list.FieldByName('Code').AsString);
              SubItems.Add(mt_list.FieldByName('CodeLen').AsString);
              SubItems.Add(mt_list.FieldByName('Count').AsString);
              SubItems.Add(mt_list.FieldByName('Rssi').AsString);
              SubItems.Add(mt_list.FieldByName('Cw').AsString);
            end;
            mt_list.Next;
          end;
        except
        end;
      finally
        FreeAndNil(item);
        //mt_list.EnableControls;

        Application.ProcessMessages;
        Sleep(40);
      end;

      //if cnt = 7 then
      //  Break;
    end;
  except
    on e: Exception do
      ShowMessage('StartThread读取错误:' + e.Message);
  end;
end;

procedure TfmMain.Button15Click(Sender: TObject);
var
  tmp: string;
begin
  //
  //ShowMessage(ConvertIntToXiaoDuan(903).ToString);
  //ShowMessage(ConvertIntToXiaoDuan(19).ToString);
  //ShowMessage(Imp(64956).ToString);
  tmp := ConvertResult(64956).ToString;
  //tmp := Imp2('FFDF');
  ShowMessage(tmp);
  Exit;
end;

function TfmMain.Byte2Hex(arrByte: array of Byte; len: Byte): string;
var
  stream: TMemoryStream;
begin
  if length(arrByte) = 0 then
    Exit;

  stream := TMemoryStream.Create;
  stream.Write(arrByte[0], len);      //Length(arrByte)
  SetLength(Result, stream.Size * 2);  //
  BinToHex(stream.Memory, PChar(Result), stream.Size);
  stream.Free;
end;


{$ENDREGION}

{$REGION 'MyRegion'}

procedure TfmMain.GetChannelItems(region: ChannelRegionItem);
var
  freq: Double;
  i: Integer;
  tmp: string;
begin
  freq := region.m_fFreqStart;
  cmbFreqStart.Items.Clear;
  for i := 0 to region.m_iFreqCount - 1 do
  begin
    tmp := Format('%.3f', [freq]);

    cmbFreqStart.Items.Add(tmp);
    freq := freq + region.m_iFreqStep / 1000;
  end;

  cmbFreqStart.ItemIndex := 0;
end;

procedure TfmMain.GetChannelCounts(region: ChannelRegionItem);
var
  freq: Double;
  i: Integer;
  item: ChannelCount;
  tmp: string;
begin
  cmbFreqEnd.Items.Clear;
  for i := 0 to region.m_iFreqCount - 1 do
  begin
    item := ChannelCount.Create;
    item.Init(region, i + 1);

    //Format('x=%.3f', [12.0]);
    if item.Region = CustomRegion then
      cmbFreqEnd.Items.Add(item.Count.ToString)
    else
    begin
      tmp := Format('%.3f', [item.Region.m_fFreqStart + (item.Count - 1) * item.Region.m_iFreqStep / 1000]);
      cmbFreqEnd.Items.Add(tmp);
    end;

    cmbFreqEnd.ItemIndex := cmbFreqEnd.Items.Count - 1;
  end;
end;

{$ENDREGION}

function TfmMain.GetDeviceParameter: Integer;
begin
  gSTRATFREI := ConvertXiaoDuanToInt(gDevPara.STRATFREI);
  gSTRATFRED := ConvertXiaoDuanToInt(gDevPara.STRATFRED);
  gSTEPFRE := ConvertXiaoDuanToInt(gDevPara.STEPFRE);

  ShowRunLog('Get STRATFREI:' + gSTRATFREI.ToString);
  ShowRunLog('Get STRATFRED:' + gSTRATFRED.ToString);
  ShowRunLog('Get STEPFRE:' + gSTEPFRE.ToString);
  ShowRunLog('Get RFIDPOWER:' + gDevPara.RFIDPOWER.ToString);
end;

procedure TfmMain.SetDeviceParameter;
begin
  gDevPara.STRATFREI := Word(ConvertIntToXiaoDuan(gSTRATFREI));
  gDevPara.STRATFRED := Word(ConvertIntToXiaoDuan(gSTRATFRED));
  gDevPara.STEPFRE := Word(ConvertIntToXiaoDuan(gSTEPFRE));

  ShowRunLog('Set STRATFREI:' + gDevPara.STRATFREI.ToString);
  ShowRunLog('Set STRATFRED:' + gDevPara.STRATFRED.ToString);
  ShowRunLog('Set STEPFRE:' + gDevPara.STEPFRE.ToString);
  ShowRunLog('Set RFIDPOWER:' + gDevPara.RFIDPOWER.ToString);
end;

{$REGION '日志'}

procedure TfmMain.ShowRunLog(p_log: string);
begin
  mmoLogs.Lines.Add(p_log);
end;

{$ENDREGION}

{$REGION '小端模式'}

//int类型 ==>> 小端模式
function TfmMain.ConvertIntToXiaoDuan(p_val: Integer): Integer;
var
  tmp: string;
begin
  tmp := Format('%.2x', [Abs(p_val)]);
  while Length(tmp) < 4 do
    tmp := '0' + tmp; // 补足前缀0
  //小端模式
  tmp := tmp[3] + tmp[4] + tmp[1] + tmp[2];

  Result := StrToInt('$' + tmp);
end;

function TfmMain.ConvertResult(p_val: Word): Word;
var
  int1, int2, int3: Word;
  Str16: string;
begin
  Str16 := Format('%.2x', [Abs(p_val)]);
  if Str16[1] in ['0'..'7'] then // 正数的补码是它本身
    Result := p_val
  else // 负数的补码是按位求反(not)末位加 1
  begin
    int1 := StrToUInt('$' + Str16);
    int2 := not int1;
    int3 := int2 + 1;
    Result := int3
  end;
end;

//小端模式 ==>> int类型
function TfmMain.ConvertXiaoDuanToInt(p_val: Integer): Integer;
var
  tmp: string;
begin
  tmp := Format('%.2x', [Abs(p_val)]);
  if Copy(tmp, 3, 1) = '8' then
  begin
    //负数
    tmp := '0' + tmp[4] + tmp[1] + tmp[2];
    Result := 0 - StrToInt('$' + tmp);
  end
  else
  begin
    tmp := tmp[3] + tmp[4] + tmp[1] + tmp[2];
    Result := StrToInt('$' + tmp);
  end;
  Result := StrToInt('$' + tmp);
end;

{$ENDREGION}

{$REGION 'Error Message'}

function TfmMain.GetErrorMessage(msg_code: Integer): string;
begin
  case msg_code of
    0:
      Result := 'Command executed successfully';
    -255:
      Result := 'Incorrect handle or parameter';
    -254:
      Result := 'Failed to connect';
    -253:
      Result := 'Internal dynamic library error';
    -241:
      Result := 'The reader responds to a data format error';
    -232:
      Result := 'The reader responded to a CRC check error';
    -239:
      Result := 'The incoming cache is too small and the data overflows';
    -238:
      Result := 'Waiting for reader response timed out';
    -237:
      Result := 'An error occurred writing data to the reader';
    -236:
      Result := 'An error occurred while reading data from the reader';
    -240:
      Result := 'Subsequent data transmission is not complete';
    -234:
      Result := 'The network connection has not been established';
    -233:
      Result := 'The network connection has been disconnected';
    -231:
      Result := 'Download data verification error';
    -230:
      Result := 'Data download error, data write error';
    -229:
      Result := 'Data download failed. Procedure';
  else
    Result := 'Unknow error code:' + msg_code.ToString;
  end;
end;

{$ENDREGION}

{ TTagItem }

destructor TTagItem.Destroy;
begin
  SetLength(m_code, 0);
end;

procedure TTagItem.Init(tagInfo: tagInfo);
begin
  m_len := tagInfo.m_len;         // 数据长度
  m_rssi := tagInfo.m_rssi;
  m_ant := tagInfo.m_ant;
  m_channel := tagInfo.m_channel;

  if (m_len > 0) then
  begin
    SetLength(m_code, m_len);
    //CopyMemory(Destination: Pointer; Source: Pointer; Length: NativeUInt);
    CopyMemory(@m_code[0], @(tagInfo.m_code[0]), m_len);
  end
  else
    SetLength(m_code, 0);
end;

end.

