unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs,
  Buttons, StdCtrls, ExtCtrls, Utils, uIntfStrConsts, Synaser,FileUtil,LCLProc
  ,ComCtrls, ActnList, Menus, Spin, EditBtn, XMLPropStorage, uUsb
  {$IFDEF WINDOWS}
  ,windows
  {$ENDIF}
  ;

type
  { TfMain }

  TfMain = class(TForm)
    acInfo: TAction;
    bSendToBootmode: TBitBtn;
    ImageList2: TImageList;
    lMessage: TLabel;
    miInfo: TMenuItem;
    miLanguage: TMenuItem;
    pBootmode: TPanel;
    pChild: TPanel;
    pDestination: TPanel;
    pSelect: TPanel;
    Properties: TXMLPropStorage;
    Splitter1: TSplitter;
    ActionList1: TActionList;
    MainMenu1: TMainMenu;
    StatusBar: TStatusBar;
    acSendToBootMode: TAction;
    tvProgrammer: TTreeView;
    procedure acInfoExecute(Sender: TObject);
    procedure bSendToBootmodeClick(Sender: TObject);
    procedure ControllerGetDeviceClass(VendorID, DeviceID: word;
      var aClass: TUSBDeviceClass);
    procedure ControllerUSBArrival(Sender: TObject);
    procedure ControllerUSBRemove(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure NewMItemClick(Sender: TObject);
    procedure tvProgrammerGetSelectedIndex(Sender: TObject; Node: TTreeNode);
    procedure tvProgrammerSelectionChanged(Sender: TObject);
  private
    { private declarations }
    Language : string;
    Controller : TUSBController;
  public
    { public declarations }
    procedure SetLanguage(Lang : string);
  end;

const
  FUNC_TYPE           = $FE;
  FUNC_WRITE_EEP      = 4;
  FUNC_WRITE_PAGE     = 2;
  FUNC_LEAVE_BOOT     = 1;
  FUNC_GET_PAGESIZE   = 3;
  FUNC_GET_CONTROLLER = 5;
  FUNC_GET_MCUCSR     = 6;
  FUNC_START_BOOTLOADER = 30;

  CONTROLLER_ATMEGA8          = 1;
  CONTROLLER_ATMEGA88         = 2;
  CONTROLLER_ATMEGA168        = 3;

var
  fMain: TfMain;
{$IFDEF MSWINDOWS}
  PrevWndProc: WNDPROC;
{$ENDIF}

implementation

uses uBootloader,uBitbanging,uUSBasp,uI2CLogger,uToolHelp
     ,uInfo,uLibUSBDevice,uUSBSerialDevice{,htmlconvert};

{ TfMain }

procedure TfMain.FormCreate(Sender: TObject);
var
  i: Integer;
  sl: TStringList;
  NewMItem: TMenuItem;
begin
  Controller := TUSBController.Create(Self);
  Controller.OnUSBArrival:=@ControllerUSBArrival;
  Controller.OnUSBRemove:=@ControllerUSBRemove;
  Controller.OnGetDeviceClass:=@ControllerGetDeviceClass;
  Controller.Enumerate;
  while pChild.ComponentCount > 0 do
    begin
      TWinControl(pDestination.Components[0]).Parent := nil;
      TWinControl(pDestination.Components[0]).Hide;
    end;
  Language := 'Deutsch';
  ForceDirectories(GetConfigDir('usbavrlab'));
  Properties.FileName := GetConfigDir('usbavrlab')+'usbavrlab.xml';
  Properties.Restore;
  Top := StrToIntDef(Properties.StoredValue['TOP'],Top);
  Left := StrToIntDef(Properties.StoredValue['LEFT'],Left);
  Height := StrToIntDef(Properties.StoredValue['HEIGHT'],Height);
  Width := StrToIntDef(Properties.StoredValue['WIDTH'],Width);
  pSelect.Width := StrToIntDef(Properties.StoredValue['HDIVIDER'],pSelect.Width);
  sl := TStringList.Create;
  if FileExists(AppendPathDelim(AppendPathDelim(ProgramDirectory) + 'languages')+'languages.txt') then
    sl.LoadFromFile((AppendPathDelim(AppendPathDelim(ProgramDirectory) + 'languages')+'languages.txt'));
  for i := 0 to sl.Count-1 do
    begin
      NewMItem := TMenuItem.Create(nil);
      NewMItem.Caption := sl[i];
      NewMItem.AutoCheck := True;
      NewMItem.OnClick :=@NewMItemClick;
      NewMItem.GroupIndex := 11;
      miLanguage.Add(NewMItem);
      if UpperCase(NewMItem.Caption) = UpperCase(Properties.StoredValue['LANGUAGE']) then
        begin
          NewMItem.Checked := True;
          Language := Properties.StoredValue['LANGUAGE'];
        end;
    end;
  sl.Free;
  SetLanguage(Language);
  fInfo := TfInfo.Create(Self);
  with fInfo do
    begin
      Version := {$I version.inc};
      Version := Version+{$I revision.inc} / 100;
      ProgramName := 'USB AVR Lab Tool';
      Copyright := '2007-2012 C.Ulrich';
      InfoText := strInfo;
    end;
  fInfo.SetLanguage;
end;

procedure TfMain.acInfoExecute(Sender: TObject);
begin
  fInfo.Showmodal;
end;

procedure TfMain.bSendToBootmodeClick(Sender: TObject);
var
  Dev: TUSBDevice;
  Port: TBlockSerial;
begin
  if not Assigned(tvProgrammer.Selected) then exit;
  Dev := TUSBDevice(tvProgrammer.Selected.Data);
  if Dev is TUSBSerialDevice then
    begin
      Port := TBlockSerial.Create;
      Port.Config(9600,8,'N',SB1,False,False);
      Port.Connect(Dev.USBSerialPort);
      if Port.LastError = 0 then
        begin
          Port.SendString('boot'+Char($D)+Char($D));
        end;
      Port.Free;
    end
  else if Dev is TLibUSbDevice then
    begin
      if TLibUSBDevice(Dev).OpenDevice then
        begin
          TLibUSBDevice(Dev).SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_START_BOOTLOADER, 0, 0,nil, 0, 5000);
          TLibUSBDevice(Dev).CloseDevice;
        end;
    end;
end;

procedure TfMain.ControllerGetDeviceClass(VendorID, DeviceID: word; var aClass: TUSBDeviceClass);
begin
  if  ((VendorID = $16C0)
  and
      ((DeviceID = $05dc)
      ))
  then
    begin
      aClass := TLibUSBDevice;
    end
  else if ((VendorID = $16C0) and (DeviceID = $05e1)) then
    aClass := TUSBSerialDevice
  else if ((VendorID = $03eb) and (DeviceID = $2104)) then  //AVRISPmkII
    aClass := TLibUSBDevice
  else if ((VendorID = $03eb) and (DeviceID = $2103)) then  //JTAGICEmkII
    aClass := TLibUSBDevice
  else if ((VendorID = $0403) and (DeviceID = $C631)) then  //I2C Tiny USB
    aClass := TLibUSBDevice
  ;
end;

procedure TfMain.ControllerUSBArrival(Sender: TObject);
var
  aNode: TTreeNode = nil;
  Typ : byte;
begin
  if  ((TUSBDevice(Sender).VendorID = $16C0)
  and
      ((TUSBDevice(Sender).DeviceID = $05dc)
    or (TUSBDevice(Sender).DeviceID = $05e1)
      ))
  then
    begin
      aNode := tvProgrammer.Items.Add(nil,'');
      aNode.ImageIndex:=0;
      TUSBDevice(Sender).Tag := -1;
      if TUSBDevice(Sender) is TUSBSerialDevice then
        begin
          aNode.ImageIndex:=2;
          if TUSBDevice(Sender).USBSerialPort <> '' then
            aNode.Text:=aNode.Text+' ('+TUSBDevice(Sender).USBSerialPort+')';
        end
      else if TUSBDevice(Sender) is TLibUSbDevice then
        if TlibUSBDevice(Sender).OpenDevice then
          begin
            if TlibUSBDevice(Sender).SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_TYPE, 0, 0,@typ, 1, 5000) = 1 then
              begin
                TlibUSBDevice(Sender).Tag := Typ;
                if Tag <> 1 then
                  aNode.ImageIndex:=3;
              end;
            TlibUSBDevice(Sender).CloseDevice;
          end
        else aNode.ImageIndex:=1;
    end
  else if ((TUSBDevice(Sender).VendorID = $03eb) and ((TUSBDevice(Sender).DeviceID = $2104) or ((TUSBDevice(Sender).DeviceID = $2103)))) //AVRISPmkII
       and (TUSBDevice(Sender) is TLibUSbDevice) then
    begin
      aNode := tvProgrammer.Items.Add(nil,'');
      if (TUSBDevice(Sender).DeviceID = $2104) then
        begin
          aNode.Text:='AVRISPmkII';
          aNode.ImageIndex:=4;
        end
      else
        begin
          aNode.Text:='JTAGICEmkII';
          aNode.ImageIndex:=5;
        end;
      TUSBDevice(Sender).Tag := -1;
      if TLibUSBDevice(Sender).OpenDevice then
        begin
          if TLibUSBDevice(Sender).SendControlMsg(USB_TYPE_VENDOR or USB_RECIP_DEVICE or USB_ENDPOINT_IN,FUNC_TYPE, 0, 0,@typ, 1, 5000) = 1 then
            begin
              TlibUSBDevice(Sender).Tag := -2;
              aNode.Text:='USB AVR Lab (AVRISPmkII)';
            end;
          TLibUSBDevice(Sender).CloseDevice;
        end;
    end
  else if ((TUSBDevice(Sender).VendorID = $0403) and (TUSBDevice(Sender).DeviceID = $C631)) //I2C Tiny USB
       and (TUSBDevice(Sender) is TLibUSbDevice) then
    begin
      aNode := tvProgrammer.Items.Add(nil,'');
      aNode.Text:='USB AVR Lab (I2C Interface)';
      aNode.ImageIndex:=3;
      TUSBDevice(Sender).Tag := -1;
    end
  else if (TUSBDevice(Sender).Status = dsEnumerationFailed)
       or (TUSBDevice(Sender).Status = dsDeviceFailure)
       or (TUSBDevice(Sender).Status = dsOvercurrent)
       or (TUSBDevice(Sender).Status = dsNotEnougthPower)
       then
    begin
      aNode := tvProgrammer.Items.Add(nil,strUnknowndevice);
      aNode.ImageIndex:=1;
    end;
  if Assigned(aNode) then
    aNode.Data := Sender;
  if Visible and Assigned(aNode) then
    if tvProgrammer.Items.Count = 1 then
      tvProgrammer.Selected := aNode;
end;

procedure TfMain.ControllerUSBRemove(Sender: TObject);
var
  aNode: TTreeNode;
begin
  if tvProgrammer.Items.Count = 0 then exit;
  aNode := tvProgrammer.Items[0];
  while Assigned(aNode) do
    begin
      if TObject(aNode.Data) = Sender then
        begin
          tvProgrammer.Items.Delete(aNode);
          exit;
        end;
      aNode := aNode.GetNext;
    end;
end;

procedure TfMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Controller.Free;
end;

procedure TfMain.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  Properties.StoredValue['TOP'] := IntToStr(Top);
  Properties.StoredValue['LEFT'] := IntToStr(Left);
  Properties.StoredValue['WIDTH'] := IntToStr(Width);
  Properties.StoredValue['HEIGHT'] := IntToStr(Height);
  Properties.StoredValue['HDIVIDER'] := IntToStr(pSelect.Width);
  Properties.Save;
  Properties.Active:=False;
  CanClose := True;
end;

procedure TfMain.FormShow(Sender: TObject);
begin
  SetLanguage(Language);
  if tvProgrammer.Items.Count = 1 then
    tvProgrammer.Selected := tvProgrammer.Items[0]
  else if tvProgrammer.Items.Count = 0 then
    tvProgrammerSelectionChanged(nil);
end;

procedure TfMain.NewMItemClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to miLanguage.Count-1 do
    if miLanguage[i].Caption = Language then
      miLanguage[i].Checked := false;
  TmenuItem(Sender).Checked := True;
  Language := TmenuItem(Sender).Caption;
  SetLanguage(Language);
  Properties.StoredValue['LANGUAGE'] := Language;
end;

procedure TfMain.tvProgrammerGetSelectedIndex(Sender: TObject; Node: TTreeNode);
begin
  Node.SelectedIndex:=Node.ImageIndex;
end;

procedure TfMain.tvProgrammerSelectionChanged(Sender: TObject);
var
  i: Integer;
  SR: TSearchRec;
begin
  lMessage.Visible:=False;
  fToolHelp.OpenHelp('');
  pBootmode.Visible:=False;
  for i := 0 to Screen.FormCount-1 do
    begin
      if (Screen.Forms[i] <> Application.MainForm)
      and (Screen.Forms[i].Parent = pChild) then
        begin
          Screen.Forms[i].Hide;
          Screen.Forms[i].Parent := nil;
        end;
    end;
  if tvProgrammer.Selected <> nil then
    begin
      if TUSBDevice(tvProgrammer.Selected.Data) is TUSBSerialDevice then
        begin
          fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'Serialfirmware'+'de');
          fToolHelp.Parent := pChild;
          fToolHelp.Align:= alClient;
          fToolHelp.Show;
          if TUSBDevice(tvProgrammer.Selected.Data).USBSerialPort <> '' then
            pBootmode.Visible:=True;
        end
      else if TUSBDevice(tvProgrammer.Selected.Data) is TLibUSBDevice then
        begin
          if (TUSBDevice(tvProgrammer.Selected.Data).Tag <> 1)
          and (TUSBDevice(tvProgrammer.Selected.Data).Tag <> -1)
          then
            pBootmode.Visible:=True;
          case TUSBDevice(tvProgrammer.Selected.Data).Tag of
          1:
            begin
              fBootloader.Parent := pChild;
              fBootloader.Align:=alClient;
              fBootloader.Show;
            end;
          2:
            begin
              fUSBasp.Parent := pChild;
              fUSBasp.Align:=alClient;
              fUSBasp.Show;
            end;
          3:
            begin
              fI2CLogger.Parent := pChild;
              fI2CLogger.Align:=alClient;
              fI2CLogger.Show;
            end;
          4:
            begin
              fBitbanging.Parent := pChild;
              fBitbanging.Align:=alClient;
              fBitbanging.Show;
            end;
          else
            begin
              pChild.Caption := strPleaseUseSpecialSoftware;
              fToolHelp.Parent := pChild;
              fToolHelp.Align:= alClient;
              case TUSBDevice(tvProgrammer.Selected.Data).Tag of
              -1:fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'NoDriver'+'de');
              5:fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'Logcanalyzer'+'de');
              6:fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'User'+'de');
              7:;
              8:fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'Takt'+'de');
              9:fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'Oszi'+'de');
              10:fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'Jtag'+'de');
              11:fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'Onewire'+'de');
              12:fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'OpenOCD'+'de');
              else fToolHelp.OpenHelp('');
              end;
              fToolHelp.Parent := pChild;
              fToolHelp.Align:= alClient;
              fToolHelp.Show;
            end;
          end;
        end
      else if tvProgrammer.Selected.ImageIndex = 1 then
        begin
          fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'Defectfirmware'+'de');
          fToolHelp.Parent := pChild;
          fToolHelp.Align:= alClient;
          fToolHelp.Show;
        end;
    end
  else
    begin
      fToolHelp.OpenHelp('USBAVR-ISP-Firmwares'+'Nofirmware'+'de');
      fToolHelp.Parent := pChild;
      fToolHelp.Align:= alClient;
      fToolHelp.Show;
    end;
end;

procedure TfMain.SetLanguage(lang : string);
begin
  //TODO:LoadLanguage(Lang);
end;

initialization
  {$I umain.lrs}

end.

