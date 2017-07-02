unit uToolHelp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, Ipfilebroker, IpHtml, Utils, uIntfStrConsts, LCLIntf;

type

  { TSimpleIpHtml }

  TSimpleIpHtml = class(TIpHtml)
  public
    property OnGetImageX;
  end;

  { TfToolHelp }

  TfToolHelp = class(TForm)
    HelpViewer: TIpHtmlPanel;
    Panel1: TPanel;
    procedure HelpViewerHotClick(Sender: TObject);
  private
    FFilename: string;
    { private declarations }
    OldPath : string;
    procedure HTMLGetImageX(Sender: TIpHtmlNode; const URL: string;var Picture: TPicture);
  public
    { public declarations }
    property Filename : string read FFilename;
    procedure OpenHelp(fName : string);
  end;

var
  fToolHelp: TfToolHelp;

implementation

{ TfToolHelp }

procedure TfToolHelp.HelpViewerHotClick(Sender: TObject);
var
  NodeA: TIpHtmlNodeA;
  NewFilename: String;
  realFn: String;
begin
  if HelpViewer.HotNode is TIpHtmlNodeA then
    begin
      NodeA:=TIpHtmlNodeA(HelpViewer.HotNode);
      NewFilename:=NodeA.HRef;
      if Uppercase(NodeA.Target) = '_BLANK' then
        begin
          if not FileExists(NewFilename) then
            realFn := OldPath+NewFileName
          else
            realFn := newFileName;
          realFN := StringReplace(realFN,'\',DirectorySeparator,[rfReplaceAll]);
          realFN := StringReplace(realFN,'/',DirectorySeparator,[rfReplaceAll]);
          realFN := Stringreplace(realFn,DirectorySeparator+DirectorySeparator,DirectorySeparator,[rfReplaceAll]);
          OpenURL(realFN);
        end
      else
        begin
          OpenHelp(NewFilename);
        end;
    end;
end;

procedure TfToolHelp.HTMLGetImageX(Sender: TIpHtmlNode; const URL: string;
  var Picture: TPicture);
var
  realFN : string;
begin
  try
    if Picture=nil then
      Picture:=TPicture.Create;
    realFN := URL;
    if not FileExists(URL) then
      realFn := OldPath+URL
    else
      realFn := URL;
    Picture.LoadFromFile(realFN);
  except
  end;
end;

procedure TfToolHelp.OpenHelp(fName: string);
var
  aName: String;
  fs: TFileStream;
  NewHTML: TSimpleIpHtml;
  sStream: TStringStream;
  ss: TStringStream;
  tmp: String;
begin
  aName := AppendPathDelim(AppendPathDelim(ExtractFilePath(Application.Exename)+'help'))+lowercase(fName)+'.html';
  if FileExists(aName) then
    begin
      fs:=TFileStream.Create(aName,fmOpenRead);
      ss := TStringstream.Create('');
      ss.CopyFrom(fs,0);
      tmp := (ss.DataString);
      ss.Free;
      fs.Free;
      ss := TStringStream.Create(tmp);
      FFileName := aName;
      OldPath := ExtractFilePath(aName);
      try
        NewHTML:=TSimpleIpHtml.Create; // Beware: Will be freed automatically by HelpViewer
        NewHTML.OnGetImageX:=@HTMLGetImageX;
        NewHTML.LoadFromStream(ss);
      finally
        ss.Free;
      end;
    end
  else
    begin
      NewHtml := TSimpleIpHtml.Create;
      sStream := TStringStream.Create('<html><body><p>'+(strNoHelp)+'</p></body></html>');
      NewHtml.LoadFromStream(sStream);
      sStream.Free;
    end;
  HelpViewer.SetHtml(NewHTML);
end;

initialization
  {$I utoolhelp.lrs}

end.

