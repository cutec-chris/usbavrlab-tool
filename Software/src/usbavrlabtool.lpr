program usbavrlabtool;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{.$IFDEF UseCThreads}
  cthreads,
  {.$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, umain, uIntfStrConsts, general, general_nogui, laz_synapse, uI2CLogger,
  uUSBasp, uBitbanging, uBootloader, libusb, uToolHelp, TurboPowerIPro,
  uLibUSBDevice, uUSBSerialDevice;

{$R usbavrlabtool.res}

begin
  Application.Initialize;
  Application.CreateForm(TfMain, fMain);
  Application.CreateForm(TfI2CLogger, fI2CLogger);
  Application.CreateForm(TfUSBAsp, fUSBAsp);
  Application.CreateForm(TfBitbanging, fBitbanging);
  Application.CreateForm(TfBootloader, fBootloader);
  Application.CreateForm(TfToolHelp, fToolHelp);
  Application.Run;
end.

