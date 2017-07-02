unit uBootloader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, ComCtrls, StdCtrls, Buttons, EditBtn
  ,uEncrypt
  ;

type
  Bytearray = array of byte;

  { TfBootloader }

  TfBootloader = class(TForm)
    bProgram: TBitBtn;
    bStart: TBitBtn;
    bWriteSTK500Params: TButton;
    cbISPSpeed: TComboBox;
    eSoftwareVersion: TEdit;
    feOwnFirmware: TFileNameEdit;
    lbPrograms: TListBox;
    lController: TLabel;
    lFirmware: TLabel;
    lISPSpeed: TLabel;
    lPageSize: TLabel;
    lSTK500SoftwareVersion: TLabel;
    lUserFirmware: TLabel;
    pcMain: TPageControl;
    pClient: TPanel;
    ProgressBar1: TProgressBar;
    rgProtocol: TRadioGroup;
    Splitter1: TSplitter;
    tsLoad: TTabSheet;
    tsOptions: TTabSheet;
    procedure bProgramClick(Sender: TObject);
    procedure bStartClick(Sender: TObject);
    procedure bWriteSTK500ParamsClick(Sender: TObject);
    procedure feOwnFirmwareAcceptFileName(Sender: TObject; var Value: String);
    procedure FormShow(Sender: TObject);
    procedure lbProgramsSelectionChange(Sender: TObject; User: boolean);
  private
    { private declarations }
  public
    { public declarations }
    PageSize : word;
    StartAddress : Integer;
    ProgramBuffer : Bytearray;
    Controller_long_str : string;
    Controller_str : string;
    Controller : Integer;
    procedure LoadCodedHexFile(Filename: string);
    procedure LoadHexFile(Filename : string);
  end;

var
  fBootloader: TfBootloader;

implementation

uses uMain,uIntfStrConsts,Utils,uToolHelp,uLibUsbDevice{,htmlconvert},uInfo;

{ TfBootloader }

procedure TfBootloader.bWriteSTK500ParamsClick(Sender: TObject);
var
  Page: Integer;
  res: LongInt;
  Addr: byte;
  Data: byte;
  Device: TLibUSBDevice;
begin
  if pos('.',eSoftwareVersion.Text) = 0 then
    begin
      Showmessage(strInvalidSoftwareVersion);
      exit;
    end;
  Device := TLibUSBDevice(fMain.tvProgrammer.Selected.Data);
  if Device.OpenDevice then
    begin
      Addr := 1;
      Data := StrToInt('$'+copy(eSoftwareVersion.Text,0,pos('.',eSoftwareVersion.Text)-1));
      res := Device.SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_WRITE_EEP,Data shl 8 or Addr,0,nil,0, 5000);
      Addr := 2;
      Data := StrToInt('$'+copy(eSoftwareVersion.Text,pos('.',eSoftwareVersion.Text)+1,length(eSoftwareVersion.Text)));
      res := Device.SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_WRITE_EEP,Data shl 8 or Addr,0,nil,0, 5000);
      Addr := 3;
      Data := rgProtocol.ItemIndex;
      res := Device.SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_WRITE_EEP,Data shl 8 or Addr,0,nil,0, 5000);
      Addr := 0;
      Data := cbISPSpeed.ItemIndex+2;
      res := Device.SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_WRITE_EEP,Data shl 8 or Addr,0,nil,0, 5000);
      Device.CloseDevice;
      fMain.StatusBar.SimpleText := strOptionsUpdated;
    end;
end;

procedure TfBootloader.bProgramClick(Sender: TObject);
var
  Page: Integer;
  res: LongInt;
  Device: TLibUSBDevice;
begin
  bProgram.Enabled := False;
  if lbPrograms.SelCount=0 then
    LoadHexFile(feOwnFirmware.FileName);
  Device := TLibUSBDevice(fMain.tvProgrammer.Selected.Data);
  if Device.OpenDevice then
    begin
      ProgressBar1.Max := length(ProgramBuffer) div PageSize;
      for Page := 0 to length(ProgramBuffer) div PageSize do
        begin
          res := Device.SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_OUT,FUNC_WRITE_PAGE,Page*PageSize,0,@ProgramBuffer[Page*PageSize], PageSize, 5000);
          if res <> PageSize then
            begin
              Showmessage(Device.LastError+' '+IntToStr(res));
              bProgram.Enabled := True;
              exit;
            end;
          fMain.StatusBar.SimpleText := Format(strProgrammingPage,[Page]);
          ProgressBar1.Position := Page;
          Application.Processmessages;
        end;
      Device.CloseDevice;
      fMain.StatusBar.SimpleText := strProgrammedOK;
    end;
  ProgressBar1.Position := 0;
  bProgram.Enabled := true;
end;

procedure TfBootloader.bStartClick(Sender: TObject);
var
  res: LongInt;
  Device: TLibUSBDevice;
begin
  Device := TLibUSBDevice(fMain.tvProgrammer.Selected.Data);
  if Device.OpenDevice then
    begin
      Device.SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_LEAVE_BOOT, 0, 0,nil, 0, 5000);
      Device.CloseDevice;
    end;
end;

procedure TfBootloader.feOwnFirmwareAcceptFileName(Sender: TObject; var Value: String
  );
var
  i: Integer;
begin
  for i := 0 to lbPrograms.Count-1 do
    lbPrograms.Selected[i]:=False;
  fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'User'+'de');
  LoadHexFile(Value);
end;

procedure TfBootloader.FormShow(Sender: TObject);
var
  SR: TSearchRec;
  Device: TLibUSBDevice;
  res: LongInt;
  Version: Integer;
begin
  pcMain.Enabled:=False;
  Device := TLibUSbDevice(fMain.tvProgrammer.Selected.Data);
  if Device.OpenDevice then
    begin
      res := Device.SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_GET_CONTROLLER, 0, 0,@Controller, 1, 5000);
      if res <> 1 then
        begin
          Showmessage(strErrorConnectingToDevice+' ('+Device.LastError+')');
          exit;
        end;
      Version := 0;
      if Controller > 10 then
        begin
          Version := Controller div 10;
          Controller := Controller mod 10;
        end;
      case Controller of
      CONTROLLER_ATMEGA8:
        begin
          Controller_str := 'm8_';
          Controller_long_str := 'ATMega8(L)';
        end;
      CONTROLLER_ATMEGA88:
        begin
          Controller_str := 'm88_';
          Controller_long_str := 'ATMega88(V)';
        end;
      CONTROLLER_ATMEGA168:
        begin
          Controller_str := 'm168_';
          Controller_long_str := 'ATMega168(V)';
        end;
      end;
      lController.Caption := strController+' : '+Controller_long_str;
      res := Device.SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_GET_PAGESIZE, 0, 0,@fBootloader.PageSize, 2, 5000);
      if res <> 2 then
        begin
          Showmessage(strErrorConnectingToDevice+' ('+Device.LastError+')');
          exit;
        end;
      fBootloader.PageSize := (fBootloader.PageSize shr 8)+(fBootloader.PageSize shl 8);
      lPageSize.Caption := strPageSize+' : '+IntToStr(PageSize);
      lbPrograms.Clear;
      if FindFirst(ExtractFilePath(Application.exename) + DirectorySeparator + 'data' + DirectorySeparator +Controller_str+'*.hex', faAnyFile and not faDirectory, SR) = 0 then
        try
          repeat
            lbPrograms.Items.Add(copy(SR.Name,length(Controller_str)+1,rpos('.',SR.Name)-1-length(Controller_str)));
          until FindNext(SR) <> 0;
        finally
          Sysutils.FindClose(SR);
        end;
      fToolHelp.Parent := pClient;
      fToolHelp.Align:=alClient;
      fToolHelp.Show;
      pcMain.Enabled:=True;
    end;
end;

procedure TfBootloader.lbProgramsSelectionChange(Sender: TObject; User: boolean
  );
var
  sl: TStringList;
  i: Integer;
  OurOS: String;
  ThereOS: String;
  Found: Boolean;
begin
  fMain.lMessage.Visible:=False;
  LoadCodedHexFile(ExtractFilePath(Application.exename) + DirectorySeparator + 'data' + DirectorySeparator + Controller_str+lbPrograms.Items[lbPrograms.ItemIndex]+'.hex');
  fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+copy(lbPrograms.Items[lbPrograms.ItemIndex],0,rpos('_',lbPrograms.Items[lbPrograms.ItemIndex])-1)+'de');
  if FileExists(fToolHelp.Filename) then
    begin
      sl := TStringList.Create;
      sl.LoadFromFile(fToolHelp.Filename);
      //TODO:sl.Text:=HTMLtoTXT(sl.text);
      while (sl.Count > 0) and (uppercase(trim(sl[0])) <> 'BETRIEBSYSTEME') do
        sl.Delete(0);
      if (sl.Count > 0) and (uppercase(trim(sl[0])) = 'BETRIEBSYSTEME') then
        begin
          sl.Delete(0);
          OurOS := Uppercase(trim(fInfo.lOperatingSystemValue.Caption));
          OurOS := StringReplace(OurOS,' ','',[rfReplaceall]);
          Found := False;
          for i := 0 to sl.Count-1 do
            begin
              if trim(sl[i]) = '' then continue;
              ThereOS := Uppercase(trim(sl[i]));
              ThereOS := StringReplace(ThereOS,' ','',[rfReplaceall]);
              if copy(OurOS,0,length(ThereOS)) = ThereOS then
                Found := True;
            end;
          if not Found then
            begin
              fMain.lMessage.Caption:=strOSNotFoundforFirmware;
              fMain.lMessage.Visible:=True;
            end;
        end;
      sl.Free;
    end;
end;

function GetIHexAddress(Hexline : string) : Integer;
var
  t: String;
begin
  Result := -1;
  if Hexline[1]=':' then
    begin
      t:='$'+copy(HexLine,4,4); // get address
      Result:=strtoint(t);
    end;
end;

function ReadIHexLine(HexLine:string;var Buf : bytearray):integer;
var
  ADDR,
  count:integer;
  CHKSUM,SUMLINE,RECLEN,RECTYPE,DATA:byte;
  t:shortstring;
  tmpline : string;
begin
  result := 0;
  tmpline := hexline;
  if tmpline[1]=':' then
    begin
      t:='$'+copy(HexLine,2,2);   // get length
      RECLEN:=strtoint(t);
      CHKSUM:=0;
      CHKSUM:=CHKSUM+RECLEN;
      t:='$'+copy(HexLine,4,4); // get address
      ADDR:=strtoint(t);
      CHKSUM:=CHKSUM+lo(ADDR)+hi(ADDR);
      t:='$'+copy(HexLine,8,2);
      RECTYPE:=strtoint(t);
      CHKSUM:=CHKSUM+RECTYPE;
      tmpline := copy(tmpline,10,length(tmpline));
      case RECTYPE of
      0:// datablock
        begin
          count:=0;
          while (count < RECLEN) do
            begin
              t:='$'+copy(tmpline,0,2);
              if length(tmpline) > 2 then
                tmpline := copy(tmpline,3,length(tmpline));
              DATA:=strtoint(t);
              CHKSUM:=CHKSUM+DATA;
              if length(Buf) < ADDR+count+1 then
                SetLength(Buf,ADDR+count+1);
              Buf[ADDR+count]:=DATA;
              inc(count);
            end;
          t:='$'+tmpline;
          SUMLINE:=strtoint(t);
        end;
      1: // end of file
        begin
          t:='$'+copy(HexLine,10,2);
          SUMLINE:=strtoint(t);
          result:=1;
        end;
      else
        begin
          result := -2;  // invalid record type
          exit;
        end;
      end; //case
      // test checksum
      DATA:=SUMLINE+CHKSUM;
//      if (DATA<>0) then result:=-3; // checksum error
    end
  else result:=-1; // no record
end;

procedure TfBootloader.LoadHexFile(Filename: string);
var
  f : Textfile;
  Res: LongInt;
  tmp : string;
  MaxSize: Integer;
begin
  bProgram.Enabled := false;
  Setlength(ProgramBuffer,0);
  if fMain.tvProgrammer.Selected = nil then
    exit;
  StartAddress := 99999999;
  AssignFile(f,(Filename));
  Reset(f);
  while not EOF(f) do
    begin
      readln(f,tmp);
      try
      if (GetIHexAddress(tmp) < StartAddress) and (GetIHexAddress(tmp) > -1) then
        StartAddress := GetIHexAddress(tmp);
      Res := ReadIHexLine(tmp,ProgramBuffer);
      except
        Showmessage(tmp);
      end;
      if Res < 0 then
        begin
          Showmessage(strInvalidHexFile+' '+IntToStr(res)+' '+tmp);
          exit;
        end;
    end;
  if Res <> 1 then
    Showmessage(strInvalidHexFile+' '+IntToStr(res));
  MaxSize := 6140;
  if Controller > CONTROLLER_ATMEGA88 then
    MaxSize := 14335;
  if length(ProgramBuffer) > MaxSize then
    begin
      Showmessage(strHexFileToBig);
      Setlength(ProgramBuffer,0);
      CloseFile(f);
      exit;
    end;
  fMain.StatusBar.SimpleText := Format(strFirmwareLoadedOK,[length(ProgramBuffer)]);
  bProgram.Enabled := True;
  CloseFile(f);
end;

procedure TfBootloader.LoadCodedHexFile(Filename: string);
var
  f : Textfile;
  Res: LongInt;
  tmp,tmp1 : string;
  MaxSize: Integer;
const
  my_key = 928371;
begin
  bProgram.Enabled := false;
  Setlength(ProgramBuffer,0);
  if fMain.tvProgrammer.Selected = nil then
    exit;
  StartAddress := 99999999;
  AssignFile(f,Filename);
  Reset(f);
  while not EOF(f) do
    begin
      readln(f,tmp);
      if copy(tmp,0,1) <> ':' then
        tmp1 := Decrypt(tmp, my_key)
      else
        tmp1 := tmp;
      try
      if (GetIHexAddress(tmp) < StartAddress) and (GetIHexAddress(tmp) > -1) then
        StartAddress := GetIHexAddress(tmp);
      Res := ReadIHexLine(tmp1,ProgramBuffer);
      except
        Showmessage(tmp);
      end;
      if Res < 0 then
        begin
          Showmessage(strInvalidHexFile+' '+IntToStr(res)+' '+tmp1);
          exit;
        end;
    end;
  if Res <> 1 then
    Showmessage(strInvalidHexFile+' '+IntToStr(res));
  MaxSize := 6140;
  if Controller > CONTROLLER_ATMEGA88 then
    MaxSize := 14335;
  if length(ProgramBuffer) > MaxSize then
    begin
      Showmessage(strHexFileToBig);
      Setlength(ProgramBuffer,0);
      CloseFile(f);
      exit;
    end;
  fMain.StatusBar.SimpleText := Format(strFirmwareLoadedOK,[length(ProgramBuffer)]);
  bProgram.Enabled := True;
  CloseFile(f);
end;

initialization
  {$I ubootloader.lrs}

end.

